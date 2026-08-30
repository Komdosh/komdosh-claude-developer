# Observability

## Metrics (Micrometer)

- Naming: `<org>.<service>.<subject>.<verb>` — e.g. `acme.order-service.orders.created`.
- **Low-cardinality tags only** (`status`, `type`, `region`). Never `userId`, `orderId`, or any per-request value — that is an unbounded time-series and a PII leak.
- Register meters at startup, never lazily on first request. Inject `MeterRegistry` by constructor.
- **Timing a `suspend fun`**: Micrometer ships no suspend-aware overload, and `Timer.recordCallable` takes a synchronous `Callable` — calling it from a `suspend fun` blocks the dispatcher. Define one `Timer.recordSuspending` extension in `application/observability/` (measure `System.nanoTime()` around the block in a `try/finally`) and use it everywhere.

## Tracing

Vendor-neutral OpenTelemetry APIs only — no Zipkin/Jaeger/Datadog imports. Follow OTel semantic attribute names. **Never a PII value in a span attribute.** The exporter is per-project config; assume no specific backend.

## Logging

- **No MDC in WebFlux or coroutine paths.** MDC is ThreadLocal and does not survive a suspension or dispatcher switch, so entries are lost or attach to the wrong request. Pass structured fields as log arguments instead. MDC stays acceptable in genuinely non-reactive paths (`@Scheduled`, startup).
- Domain identifiers go in structured fields, not interpolated into the message string.
- Always present: `correlationId` (from `X-Correlation-Id` or generated at ingress) and `serviceVersion`.

## Health

`/actuator/health` exposes `db` and `diskSpace` at minimum; every critical downstream dependency gets a `ReactiveHealthIndicator`.
