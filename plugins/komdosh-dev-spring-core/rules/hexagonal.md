# Hexagonal Architecture Rules

## Leaf-Module Structure

Every service must follow this module layout:

```
<service>/
├── api/                 Shared contracts (DTOs, OpenAPI), no logic
├── domain/              Pure business logic — no framework imports whatsoever
├── application/         Use-case orchestration; defines port interfaces
│   └── ports/           Port interfaces (in/out) — only domain types in signatures
├── adapters/
│   ├── inbound/         HTTP handlers, event consumers — translates external → domain
│   └── outbound/        DB, event producers, HTTP clients — implements output ports
├── boot/                Spring Boot @SpringBootApplication; wires all adapters
└── load-tests/          Gatling simulations (sibling, not child of the above)
```

## Dependency Direction (strictly enforced by ArchUnit)

```
domain  ←  application  ←  adapters/inbound
                        ←  adapters/outbound
                        ←  boot
```

- `domain` depends on **nothing** (no Spring, no jOOQ, no Kafka, no Jackson).
- `application` depends on `domain` only.
- `adapters/inbound` and `adapters/outbound` depend on `application` + `domain`.
- `boot` depends on all adapter modules; is the composition root.
- **No shortcuts**: `adapters/inbound` must NOT import from `adapters/outbound`.

## Port/Adapter Pattern

Application services depend on port **interfaces** defined in `application/ports/`:

```kotlin
// application/ports/OrderRepository.kt
interface OrderRepository {
    suspend fun findById(id: OrderId): Order?
    suspend fun save(order: Order): Order
}
```

Implementations live in `adapters/outbound/` and are injected in `boot/`.
Swapping an adapter (e.g., SQL → in-memory) must NOT require changing `domain/` or `application/`.

## ArchUnit Enforcement

Write ArchUnit tests in `tests/architecture/`:

```kotlin
@AnalyzeClasses(packagesOf = [Application::class])
class HexagonalArchitectureTest {

    @ArchTest
    val domainHasNoDeps: ArchRule = noClasses()
        .that().resideInAPackage("..domain..")
        .should().dependOnClassesThat()
        .resideInAnyPackage(
            "org.springframework..",
            "org.jooq..",
            "org.apache.kafka..",
            "com.fasterxml.jackson.."
        )

    @ArchTest
    val inboundDoesNotImportOutbound: ArchRule = noClasses()
        .that().resideInAPackage("..adapters.inbound..")
        .should().dependOnClassesThat()
        .resideInAPackage("..adapters.outbound..")
}
```
