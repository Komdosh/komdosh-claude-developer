# Observability Rules

## Metrics (Micrometer)

**Naming convention**: `<org>.<service>.<subject>.<verb>`
Examples: `acme.order-service.orders.created`, `acme.order-service.payments.failed`

Rules:
- Register all metrics at startup — never create meters lazily on first request.
- Low-cardinality tags only: `status`, `type`, `region`. Never `userId`, `orderId`, or any per-request value.
- Inject `MeterRegistry` via constructor — never access as a static singleton.

```kotlin
@Service
class OrderService(
    private val meterRegistry: MeterRegistry
) {
    private val ordersCreated = Counter.builder("acme.order-service.orders.created")
        .description("Total orders successfully created")
        .tag("env", System.getenv("ENV") ?: "unknown")
        .register(meterRegistry)

    suspend fun create(command: CreateOrderCommand): Order {
        val order = ...
        ordersCreated.increment()
        return order
    }
}
```

### Timing a `suspend fun`

Micrometer's `Timer` ships no `suspend`-aware `record` overload, and `Timer.recordCallable` expects a synchronous `Callable<T>` — calling it from a `suspend fun` blocks the dispatcher. Time manually, or define the extension once in `application/observability/`:

```kotlin
suspend inline fun <T> Timer.recordSuspending(crossinline block: suspend () -> T): T {
    val start = System.nanoTime()
    try {
        return block()
    } finally {
        record(System.nanoTime() - start, TimeUnit.NANOSECONDS)
    }
}
```

## Tracing (OTel)

- Use OpenTelemetry vendor-neutral APIs only — no Zipkin, Jaeger, or Datadog-specific imports.
- Never add PII (email, name, phone, payment data) to span attributes.
- Follow OTel semantic conventions for attribute names (`db.system`, `http.method`, etc.).
- The collector/exporter is configured per project in `application.yaml` — the plugin does not assume a specific backend.

```kotlin
val span = tracer.spanBuilder("orders.create")
    .setAttribute("order.type", command.type.name)  // low-cardinality, no PII
    .startSpan()
try {
    span.makeCurrent().use { processOrder(command) }
} finally {
    span.end()
}
```

## Structured Logging

### WebFlux / Coroutine Pipelines — No MDC

MDC is ThreadLocal and is **not safe** across coroutine suspension points or dispatcher switches. In WebFlux and coroutine code, log context must be propagated via Reactor Context or passed as explicit function parameters:

```kotlin
// CORRECT — pass structured fields explicitly
log.info("Order created: orderId={} customerId={} durationMs={}", order.id, order.customerId, elapsed)

// WRONG — MDC is unsafe in WebFlux / coroutines
MDC.put("orderId", order.id.toString())
log.info("Order created")
MDC.remove("orderId")
```

### Non-Reactive Paths — MDC Acceptable

In non-reactive, non-coroutine code paths (e.g., `@Scheduled` tasks, startup logic, `Dispatchers.IO` blocks that do not themselves suspend), MDC is acceptable.

### Required Fields

Always include in structured log output:
- `correlationId` — from the request `X-Correlation-Id` header or generated at ingress
- `serviceVersion` — from `spring.application.version` or build info
- Relevant domain entity IDs as structured fields (not in the message string)

## Health Indicators

- Expose `/actuator/health` with `db` and `diskSpace` at minimum.
- Add a custom `ReactiveHealthIndicator` for any critical downstream dependency:

```kotlin
@Component
class PaymentGatewayHealthIndicator(private val client: PaymentGatewayClient) : ReactiveHealthIndicator {
    override fun health(): Mono<Health> =
        client.ping()
            .map { Health.up().build() }
            .onErrorReturn(Health.down().withDetail("reason", "ping failed").build())
}
```
