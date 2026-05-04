# Testing Rules

## Test Types and Placement

```
tests/
├── unit/          Pure logic tests — no I/O, no Spring context
├── integration/   Adapter tests against real infrastructure (Testcontainers)
└── architecture/  ArchUnit dependency rules
```

Unit tests live in the module they test. Integration tests for `adapters/outbound/` live in that module (Testcontainers spins a real DB). Full end-to-end integration tests live in `boot/`.

## Coroutine Tests — Always `runTest`

Never use `runBlocking` in tests. Use `runTest` from `kotlinx-coroutines-test`:

```kotlin
@Test
fun `should return 404 when order not found`() = runTest {
    val result = orderService.findById(OrderId(UUID.randomUUID()))
    assertThat(result).isNull()
}
```

For time-dependent behavior, use `TestCoroutineScheduler`:

```kotlin
@Test
fun `should expire after timeout`() = runTest {
    val scheduler = testScheduler
    service.start()
    scheduler.advanceTimeBy(Duration.ofSeconds(31).toMillis())
    assertThat(service.isExpired()).isTrue()
}
```

## Fakes Over Mocks

Prefer hand-written fakes for all `application/ports/` interfaces:

```kotlin
class FakeOrderRepository : OrderRepository {
    private val store = mutableMapOf<OrderId, Order>()

    override suspend fun findById(id: OrderId): Order? = store[id]
    override suspend fun save(order: Order): Order = order.also { store[order.id] = it }
    override suspend fun delete(id: OrderId) { store.remove(id) }
    fun all(): List<Order> = store.values.toList()  // test helper
}
```

Place fakes in a `testkit/` source set or a shared test module. Do NOT duplicate fake logic across test files.

## MockK — Narrow Use Only

MockK is permitted only for:
1. Final classes from third-party libraries that cannot be faked (e.g., `ReactiveJwtDecoder`).
2. Cases where writing a full fake is disproportionate to the test value.

Never use Mockito — its bytecode manipulation is fragile with Kotlin.

## Fixed Clocks

Inject `java.time.Clock` into every service that needs the current time. In tests:

```kotlin
val clock = Clock.fixed(Instant.parse("2024-06-15T09:00:00Z"), ZoneOffset.UTC)
```

Never call `Instant.now()` or `LocalDate.now()` directly in production code.

## H2 in Unit Tests

H2 is acceptable for lightweight unit tests that test query-building logic without needing a full Postgres. For integration tests that test actual `adapters/outbound/` behaviour, use a real Postgres via Testcontainers.

## Integration Tests — Testcontainers Required

```kotlin
@Testcontainers
@SpringBootTest
class OrderRepositoryIT {
    companion object {
        @Container
        @JvmStatic
        val postgres = PostgreSQLContainer<Nothing>("postgres:16-alpine")
            .withDatabaseName("testdb")

        @DynamicPropertySource
        @JvmStatic
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.r2dbc.url") {
                "r2dbc:postgresql://${postgres.host}:${postgres.firstMappedPort}/testdb"
            }
            registry.add("spring.r2dbc.username") { postgres.username }
            registry.add("spring.r2dbc.password") { postgres.password }
        }
    }
}
```

## Test Naming

Use backtick names:

```kotlin
@Test
fun `should reject order when customer has exceeded limit`() = runTest { ... }
```

## Controller Tests

Use `@WebFluxTest` with faked services — no full `@SpringBootTest` for controller-layer tests:

```kotlin
@WebFluxTest(OrderController::class)
class OrderControllerTest {
    @MockkBean
    lateinit var orderService: OrderService
    // ...
}
```
