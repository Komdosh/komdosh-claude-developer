# Testing

## Placement

`tests/unit/` (no I/O, no Spring context) · `tests/integration/` (Testcontainers) · `tests/architecture/` (ArchUnit). Outbound-adapter integration tests live in that adapter's module; end-to-end tests live in `boot/`.

## Rules

- **`runTest`, never `runBlocking`** — `runBlocking` masks suspension behaviour and hides timing bugs. Use `testScheduler.advanceTimeBy` for time-dependent behaviour rather than real delays.
- **Hand-written fakes over mocks for every `application/ports/` interface.** Fakes live in a shared `testkit/` source set — never duplicated per test file.
- **MockK only** for third-party finals that cannot be faked (e.g. `ReactiveJwtDecoder`), or where a full fake is disproportionate. **Never Mockito** — its bytecode manipulation is fragile against Kotlin.
- **Inject `java.time.Clock`**; tests use `Clock.fixed`. `Instant.now()` / `LocalDate.now()` never appear in production code.
- Outbound-adapter integration tests run against **real Postgres via Testcontainers**, wired with `@DynamicPropertySource`. H2 is acceptable only for unit tests of query-building logic.
- Controller tests use `@WebFluxTest` with faked services — not a full `@SpringBootTest`.
