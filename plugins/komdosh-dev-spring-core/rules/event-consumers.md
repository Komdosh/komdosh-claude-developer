# Event Consumer Rules

Rules for Kafka, SQS, RabbitMQ, or any other message-broker consumer. Producers (writes that need to publish events alongside a DB change) follow the **outbox pattern** documented in [`rules/persistence.md`](persistence.md) — this file covers the read/consume side.

## Topic / Queue Naming

- Lowercase, dot-separated, plural noun: `orders.created`, `payments.authorised`, `inventory.stock-updated`.
- Domain event topics: `<aggregate>.<past-tense-verb>` (`orders.created`, `users.deactivated`).
- Command topics (rare — prefer HTTP for commands): `<aggregate>.<imperative-verb>.commands` (`orders.cancel.commands`).
- DLQ suffix: `<original-name>.dlq` (`orders.created.dlq`). Never bake the DLQ name into business code — let infrastructure (Kafka Streams, SQS redrive policy, RabbitMQ DLX) route to it.

## Offset / Acknowledgement Policy

| Broker | Commit / ack moment |
|---|---|
| Kafka | **After** the handler succeeds AND any DB write commits. Use manual commit (`enable.auto.commit=false`); commit per batch, not per record. |
| SQS | Delete the message **after** the handler succeeds. SQS at-least-once delivery means you may see duplicates — see Idempotency below. |
| RabbitMQ | Manual ack **after** handler success. On failure, `nack` with `requeue=false` so the broker routes via the DLX. Never `requeue=true` in a hot loop. |

Never commit/ack **before** the handler runs. That converts at-least-once into at-most-once and silently drops events on a crash.

## Idempotency Is Not Optional

Every consumer MUST be idempotent. The broker will redeliver — that is the contract, not an edge case.

- **Idempotency key**: pick a stable field on the event (`eventId`, `orderId + version`, `correlationId`). Reject if seen.
- **Storage for the key**: a `processed_events(event_id, processed_at)` table with a unique index. Insert in the same DB transaction as the side effect; if the insert fails on the unique constraint, the event was already processed — ack and move on.
- **TTL**: keep processed-event rows for at least the broker's redelivery window (Kafka: retention.ms; SQS: visibility timeout × max receives).

Do NOT use in-memory dedupe (`Set<UUID>` in the JVM). It does not survive restart, and consumers are usually multi-instance.

```kotlin
@Component
class OrderCreatedConsumer(
    private val processed: ProcessedEventRepository,
    private val orderProjection: OrderProjection,
    private val txOperator: TransactionalOperator,
) {
    suspend fun handle(event: OrderCreated) =
        txOperator.executeAndAwait {
            // unique constraint on event_id makes this the dedupe gate
            val inserted = processed.tryInsert(event.eventId)
            if (inserted) {
                orderProjection.upsert(event)
            } // else already processed; commit the empty tx and ack
        }
}
```

## Error Handling

A handler can fail for three reasons. Each gets a different policy:

| Failure mode | Example | Policy |
|---|---|---|
| **Transient** | Downstream HTTP 503, network timeout, DB connection dropped | Retry with exponential backoff. After max attempts, route to DLQ. |
| **Poison message** | Malformed payload, schema mismatch, business invariant violation | Do NOT retry. Route to DLQ on first failure. Log enough to diagnose. |
| **Programmer error** | NPE, missing field, dependency mis-wired | Same as poison — route to DLQ, alert. Do not block the partition. |

Bake the policy into the consumer wrapper so business code only handles the happy path:

```kotlin
suspend fun handle(record: ConsumerRecord<String, OrderCreatedV1>) {
    runCatching { businessHandler.handle(record.value()) }
        .onFailure { ex ->
            when (ex) {
                is TransientException -> throw ex                  // let the framework retry
                else                  -> dlq.send(record, cause = ex)
            }
        }
}
```

Never `try { ... } catch (e: Exception) { logger.warn(...) }` in a consumer body — that swallows failure and silently drops events.

## Schema Evolution

- Use a schema registry (Confluent, Apicurio) for Kafka. Evolve via additive changes only (new optional fields). Removing or renaming a field requires a new topic version.
- Version the topic, not the message: `orders.created.v1`, `orders.created.v2`. Run consumers for both versions during the migration window.
- Never deserialize into `Any`/`Map<String, Any>`. Pin to a generated DTO from the registry. The DTO lives in `adapters/inbound/<consumer>/dto/` — never in `domain/` or `application/`.

## Coroutines + Consumer Threads

Spring Kafka, Spring Cloud Stream, and most reactive consumer frameworks call your handler on a dedicated thread (Kafka listener thread, RabbitMQ thread pool). That thread is **not** a coroutine dispatcher — entering coroutine code requires a bridge:

```kotlin
@KafkaListener(topics = ["orders.created.v1"], containerFactory = "orderListenerFactory")
fun onMessage(record: ConsumerRecord<String, OrderCreatedV1>, ack: Acknowledgment) {
    // Bridge: run the suspend handler to completion on this listener thread.
    // We CANNOT return Mono/Flux from a Kafka @KafkaListener.
    runBlocking(MDCContext()) {            // runBlocking IS allowed at this top-level boundary
        consumer.handle(record)
    }
    ack.acknowledge()
}
```

This is the single permitted use of `runBlocking` in production code (see [`rules/kotlin-coroutines.md`](kotlin-coroutines.md) — `runBlocking` is forbidden in WebFlux handlers and tests, but a non-reactive listener thread that the framework owns and pools is the boundary case it was designed for). Document this in code with a `// Allowed: framework-owned listener thread, see rules/event-consumers.md` comment.

For reactive consumers (Reactor Kafka, RabbitMQ Reactor), use the framework's reactive bridge instead:

```kotlin
fun consume() = receiver.receive()
    .flatMap { record -> mono { consumer.handle(record.value()) }.thenReturn(record) }
    .doOnNext { it.receiverOffset().acknowledge() }
    .subscribe()
```

## Observability

Every consumer registers:

- **Counter**: `<org>.<service>.<topic>.consumed.total` (tags: `outcome=success|dlq|retry`)
- **Counter**: `<org>.<service>.<topic>.dlq.total` (tag: `reason=transient-exhausted|poison|programmer-error`)
- **Timer**: `<org>.<service>.<topic>.handle.duration` (no per-message tags)
- **Gauge**: consumer lag (`kafka.consumer.lag`) — most clients expose this; surface it on the dashboard.

Tags are low-cardinality only — never `messageId`, `orderId`, `partition`, or any per-message value. See [`rules/observability.md`](observability.md).

Trace propagation: extract OTel context from the message headers (W3C `traceparent`) **before** entering the handler. Don't rely on MDC across the listener-thread → coroutine bridge.

## Testing

- Use **Testcontainers** (`KafkaContainer`, `LocalStackContainer` for SQS, `RabbitMQContainer`) — never embedded brokers.
- Test the consumer wrapper, not the framework. Send a message → assert side effects → assert ack happened.
- Test idempotency explicitly: send the same message twice, assert exactly one side effect.
- Test poison message: send a malformed payload, assert it lands in the DLQ topic without blocking subsequent valid messages.

```kotlin
@Test
fun `redelivered events are idempotent`() = runTest {
    val event = OrderCreated(eventId = UUID.randomUUID(), orderId = OrderId(...))
    consumer.handle(event)
    consumer.handle(event)   // redelivery
    assertThat(orderProjection.count()).isEqualTo(1)
}
```

## Forbidden Patterns

| # | Pattern | Why |
|---|---|---|
| 1 | `enable.auto.commit=true` | Commits offsets before handler runs; loses messages on crash |
| 2 | Catch-all `catch (e: Exception) { logger.warn(...) }` in handler body | Silently drops events |
| 3 | In-memory dedupe (`ConcurrentHashMap`, `Set`) | Doesn't survive restart; doesn't dedupe across instances |
| 4 | Deserializing into `Map<String, Any>` | No schema enforcement; field renames silently break |
| 5 | `requeue=true` on RabbitMQ on failure | Hot loop; pegs CPU; never reaches DLQ |
| 6 | Reading `MDC` after entering coroutine code from a listener thread | ThreadLocal; lost on dispatcher switch — pass log fields explicitly |
| 7 | Topic / queue name string literals scattered across the code | Use a single `Topics` object in `adapters/inbound/<consumer>/Topics.kt` |
| 8 | DLQ side effects from inside the main handler | Let the framework or wrapper route to DLQ; the handler should fail fast and let the wrapper handle disposition |
