# Event Consumers

Kafka, SQS, RabbitMQ, or any broker — the consume side. Producers use the outbox pattern in `rules/persistence.md`.

## Naming

`<aggregate>.<past-tense-verb>`, lowercase dot-separated (`orders.created`, `inventory.stock-updated`). Version the **topic**, not the message: `orders.created.v1`. DLQ is `<name>.dlq`, routed by infrastructure (Streams, SQS redrive, RabbitMQ DLX) — never named in business code. Topic names live in one `Topics` object per consumer, never as scattered literals.

## Commit / ack after the handler, never before

| Broker | Moment |
|---|---|
| Kafka | After handler success **and** DB commit. `enable.auto.commit=false`; commit per batch. |
| SQS | Delete after handler success. |
| RabbitMQ | Manual ack after success; on failure `nack` with `requeue=false` so the DLX routes it. |

Committing before the handler converts at-least-once into at-most-once and silently drops events on a crash.

## Idempotency is mandatory

Redelivery is the contract, not an edge case.

- Stable idempotency key from the event (`eventId`, or `aggregateId + version`).
- Persist it in `processed_events(event_id, processed_at)` with a **unique index**, inserted in the **same transaction as the side effect**. A unique-constraint failure means already-processed: ack and move on.
- Retain rows for at least the broker's redelivery window (Kafka `retention.ms`; SQS visibility timeout × max receives).
- **Never in-memory dedupe** — it doesn't survive a restart and doesn't span instances.

## Error policy — three failure modes, three answers

| Mode | Example | Policy |
|---|---|---|
| Transient | 503, timeout, dropped connection | Retry with backoff; DLQ after max attempts |
| Poison | Malformed payload, schema mismatch, invariant violation | **No retry** — DLQ on first failure |
| Programmer error | NPE, mis-wired dependency | DLQ + alert. Never block the partition |

Put this in the consumer wrapper so business code handles only the happy path. **Never `catch (e: Exception) { log.warn(...) }` in a handler body** — that swallows the failure and drops the event.

## Schema

Use a schema registry; evolve additively. Deserialize into a **generated DTO**, never `Map<String, Any>` — an unenforced schema turns a field rename into a silent data loss. The DTO lives in `adapters/inbound/<consumer>/dto/`, never in `domain/` or `application/`. Run both versions' consumers during a migration window.

## The listener-thread bridge

Spring Kafka and RabbitMQ call the handler on a framework-owned pooled thread, which is not a coroutine dispatcher and cannot return `Mono`/`Flux`. Bridging with `runBlocking` at that boundary is **the single permitted production use of `runBlocking`** (`rules/kotlin-coroutines.md` #1) — mark it with a `// Allowed: framework-owned listener thread` comment. Reactive consumers (Reactor Kafka) use the framework's own bridge (`mono { … }`) instead.

Extract OTel context from the message headers (W3C `traceparent`) **before** entering the handler; MDC does not survive the bridge.

## Observability

Per consumer: `<org>.<service>.<topic>.consumed.total` (tag `outcome`), `….dlq.total` (tag `reason`), a handle-duration timer, and consumer lag on the dashboard. Low-cardinality tags only — never `messageId`, `partition`, or a per-message value.

## Testing

Testcontainers (`KafkaContainer`, `LocalStackContainer`, `RabbitMQContainer`) — never embedded brokers. Test the wrapper, not the framework, and explicitly cover: **the same message twice yields exactly one side effect**, and **a poison payload reaches the DLQ without blocking the messages behind it**.

## Forbidden patterns

| # | Pattern | Why |
|---|---|---|
| 1 | `enable.auto.commit=true` | Commits before the handler runs; loses messages on crash |
| 2 | Catch-all `catch (e: Exception) { log.warn(…) }` in the handler | Silently drops events |
| 3 | In-memory dedupe | Doesn't survive restart or span instances |
| 4 | Deserializing into `Map<String, Any>` | No schema enforcement; renames break silently |
| 5 | RabbitMQ `requeue=true` on failure | Hot loop; never reaches the DLQ |
| 6 | Reading MDC after the listener→coroutine bridge | ThreadLocal; lost on dispatcher switch |
| 7 | Topic-name literals scattered across the code | One `Topics` object per consumer |
| 8 | Sending to the DLQ from inside the main handler | The wrapper owns disposition; the handler fails fast |
