# Platform Module Rules

Application code (`application/`, `domain/`) must depend only on **abstractions**, not on framework or library implementation types. The single source of truth for those abstractions is a leaf module called `common/` (also acceptable: `platform/`). Concrete adapters in `adapters/outbound/` and `boot/` implement the abstractions.

This rule complements [`rules/domain-purity.md`](domain-purity.md) (banned imports) and [`rules/hexagonal.md`](hexagonal.md) (module direction). Where those forbid leaks of specific packages, this file says where the abstractions go and what shape they take.

## Module Layout

```
common/
├── observability/         MetricsRegistry, MetricsCounter, MetricsTimer (Micrometer abstraction)
├── time/                  ApplicationClock (java.time.Clock wrapper or pass-through)
├── serialization/         JsonCodec (Jackson abstraction; rare — usually only at adapter boundaries)
├── transaction/           TxRunner (TransactionalOperator abstraction)
├── messaging/             OutboxPublisher, MessagePublisher (broker abstraction)
└── ids/                   IdGenerator (UUID/Snowflake abstraction)

domain/         → depends on common/ (interfaces only — never on Micrometer, jOOQ, Spring directly)
application/    → depends on common/ + domain/
adapters/outbound/  → implements common/ interfaces using concrete libraries (Micrometer, jOOQ, etc.)
boot/           → wires the implementations into the common/ interfaces
```

`common/` itself depends on **nothing** (Java standard library only — `java.time`, `java.util`, kotlinx-coroutines is acceptable). It is as pure as `domain/`.

## What Belongs in `common/`

A type belongs in `common/` if and only if:

1. The application layer needs to call it (read or write).
2. The current implementation pulls in a framework / library that we don't want in `application/` (Micrometer, jOOQ, Reactor, Jackson, Spring beyond `@Service`/`@Transactional`).
3. There is a plausible alternative implementation (test fake, in-memory, different vendor) that we want to be able to swap.

If only #1 holds (no library leak, no swap concern), `application/` calls the JDK type directly — no abstraction needed.

## Abstraction Shape Examples

### Metrics (replaces `MeterRegistry`, `Counter`, `Timer`)

```kotlin
// common/observability/MetricsRegistry.kt
package com.example.common.observability

interface MetricsRegistry {
    fun counter(name: String, vararg tags: Pair<String, String>): MetricsCounter
    fun timer(name: String, vararg tags: Pair<String, String>): MetricsTimer
}

interface MetricsCounter {
    fun increment(amount: Double = 1.0)
}

interface MetricsTimer {
    suspend fun <T> recordSuspending(block: suspend () -> T): T
}
```

```kotlin
// adapters/outbound/observability/MicrometerMetricsRegistry.kt
class MicrometerMetricsRegistry(private val delegate: io.micrometer.core.instrument.MeterRegistry) : MetricsRegistry {
    override fun counter(name: String, vararg tags: Pair<String, String>): MetricsCounter =
        MicrometerCounter(io.micrometer.core.instrument.Counter.builder(name).tags(*tags.toTagsArray()).register(delegate))
    // ...
}
```

The application service depends only on `MetricsRegistry`. `MeterRegistry` never appears in `application/` source.

### Transactions (replaces `TransactionalOperator`)

```kotlin
// common/transaction/TxRunner.kt
package com.example.common.transaction

interface TxRunner {
    suspend fun <T> inTransaction(block: suspend () -> T): T
}
```

```kotlin
// adapters/outbound/transaction/SpringTxRunner.kt
class SpringTxRunner(private val delegate: TransactionalOperator) : TxRunner {
    override suspend fun <T> inTransaction(block: suspend () -> T): T =
        delegate.executeAndAwait { block() }
}
```

### Time (often a pass-through, but worth wrapping for testability)

```kotlin
// common/time/ApplicationClock.kt
package com.example.common.time

import java.time.Clock
import java.time.Instant

interface ApplicationClock {
    fun now(): Instant
}

class JdkApplicationClock(private val delegate: Clock = Clock.systemUTC()) : ApplicationClock {
    override fun now(): Instant = delegate.instant()
}

class FixedApplicationClock(private val fixed: Instant) : ApplicationClock {
    override fun now(): Instant = fixed
}
```

The application uses `clock.now()` everywhere — never `Instant.now()` (which is hard to fake) or `java.time.Clock` directly (which is fine but loses the convention of `clock.now()`).

### Outbox Publishing (broker abstraction)

```kotlin
// common/messaging/OutboxPublisher.kt
package com.example.common.messaging

interface OutboxPublisher {
    suspend fun publish(topic: String, key: String?, payload: ByteArray, headers: Map<String, String> = emptyMap())
}
```

The Kafka, SQS, or RabbitMQ implementation lives in `adapters/outbound/messaging/`. The application service publishes via the interface only.

## What Does NOT Belong in `common/`

- **Domain types.** Order, Customer, Money — these are domain concepts. They live in `domain/`.
- **Application use cases.** OrderService, CreateOrderHandler — they live in `application/`.
- **Concrete library configuration.** The Micrometer registry instance, the jOOQ `DSLContext` — they're constructed in `boot/`.
- **DTOs and request/response shapes.** They live next to the inbound or outbound adapter that produces them.
- **Anything that's only used in one adapter.** If a Jackson `ObjectMapper` is only used by `adapters/inbound/web/`, it stays there — don't preemptively abstract it.

The goal of `common/` is to keep the **center** of the hexagon (domain + application) free of vendor coupling. Edges of the hexagon (adapters) are allowed to be vendor-coupled — that's their purpose.

## When to Introduce a `common/` Module

Introducing `common/` is a hard-to-reverse architectural decision (it changes the build graph, every import). Run [`check-adr-required`](../skills/check-adr-required/SKILL.md) first; the answer will almost always be `REQUIRED`. Capture the choice in `docs/adr/NNNN-introduce-common-platform-module.md`.

Common signals that you've reached the threshold:

- `MeterRegistry`, `Counter`, `Timer` appear in 5+ application services.
- `TransactionalOperator` is injected in 3+ application services.
- A team wants to swap the messaging broker, JSON library, or metrics backend and is blocked by widespread direct dependencies.
- The team is migrating from one vendor to another and needs a stable seam.

If only one or two services touch a vendor type, an inline private abstraction (a `private object MetricsKit { ... }` next to the service) is sufficient. Don't create a module for one or two consumers.

## ArchUnit Enforcement

Add to `tests/architecture/` once `common/` exists:

```kotlin
@ArchTest
val applicationOnlyKnowsCommonAndDomain: ArchRule = noClasses()
    .that().resideInAPackage("..application..")
    .should().dependOnClassesThat()
    .resideInAnyPackage(
        "io.micrometer..",
        "org.jooq..",
        "com.fasterxml.jackson..",
        "org.apache.kafka..",
        "io.r2dbc..",
        "reactor.core..",
    )
    .because("application must depend on common/ interfaces, not on vendor types directly")

@ArchTest
val commonHasNoVendorDeps: ArchRule = noClasses()
    .that().resideInAPackage("..common..")
    .should().dependOnClassesThat()
    .resideInAnyPackage("org.springframework..", "io.micrometer..", "org.jooq..", "com.fasterxml.jackson..")
    .because("common/ must be vendor-neutral so it can host swappable abstractions")
```

## Forbidden Patterns

| # | Pattern | Why |
|---|---|---|
| 1 | `import io.micrometer.core.instrument.MeterRegistry` in `application/` | Defeats the purpose — wraps the dependency only at the import site |
| 2 | `common/` depending on Spring or any vendor library | Defeats the purpose — `common/` becomes coupled |
| 3 | Putting domain entities in `common/` | Domain belongs in `domain/`; `common/` is for cross-cutting platform abstractions |
| 4 | Multiple "common" modules (`common-utils`, `common-time`, `common-metrics`) | One `common/` with sub-packages keeps the build graph manageable; split only when boundaries are clear and stable |
| 5 | Abstracting just for the sake of abstracting (Clock with no test fake yet, JsonCodec with one Jackson impl and no plan for swap) | YAGNI — wait for the second consumer or the test pain before introducing the abstraction |
