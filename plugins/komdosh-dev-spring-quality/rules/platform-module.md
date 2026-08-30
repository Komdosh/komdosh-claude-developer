# Platform Module (`common/`)

Keep the **centre** of the hexagon — `domain/` and `application/` — free of vendor coupling by routing every cross-cutting capability through abstractions in a leaf module called `common/` (or `platform/`). Adapters at the edges stay vendor-coupled; that is their purpose.

Complements core's `rules/domain-purity.md` (which packages are banned) and `rules/hexagonal.md` (which direction dependencies run). This file says where the abstractions live and what shape they take.

## Layout

```
common/observability/   MetricsRegistry, MetricsCounter, MetricsTimer
common/time/            ApplicationClock
common/transaction/     TxRunner
common/messaging/       MessagePublisher / OutboxPublisher
common/serialization/   JsonCodec        (rare — usually adapter-local)
common/ids/             IdGenerator
```

`domain/` and `application/` depend on `common/` interfaces · `adapters/outbound/` implements them against the real libraries · `boot/` wires the two together.

**`common/` itself depends on nothing** but the JDK and kotlinx-coroutines. It is as pure as `domain/`.

## The three-part test

A type belongs in `common/` only when **all three** hold:

1. The application layer calls it.
2. Its implementation pulls in a framework we don't want in `application/` — Micrometer, jOOQ, Reactor, Jackson, the Kafka client, R2DBC, Spring beyond `@Service`/`@Transactional`.
3. A plausible alternative implementation exists worth swapping to — a test fake, in-memory, another vendor.

Only #1? `application/` calls the JDK type directly. No abstraction.

Shapes stay minimal — `TxRunner.inTransaction(block)`, `ApplicationClock.now()`, `MetricsRegistry.counter(name, tags)`. `MetricsTimer` exposes `recordSuspending`, because that is exactly the gap Micrometer's own `Timer` leaves (`rules/observability.md`).

## What does not belong

Domain types (they're `domain/`) · use cases (`application/`) · concrete library instances like the `MeterRegistry` or `DSLContext` (constructed in `boot/`) · DTOs (next to their adapter) · **anything used by only one adapter** — an `ObjectMapper` used only by the web adapter stays there.

## When to introduce it

Introducing `common/` changes the build graph and every import — it is hard to reverse. Run core's `check-adr-required` first; the answer is almost always REQUIRED.

Threshold signals: `MeterRegistry` in 5+ application services · `TransactionalOperator` in 3+ · a vendor swap or migration blocked by widespread direct dependencies.

**Below that, a private inline abstraction next to the one service is sufficient.** Don't create a module for two consumers.

## Enforcement

Once `common/` exists, add two ArchUnit rules in `tests/architecture/`: `application` must not depend on `io.micrometer..`, `org.jooq..`, `com.fasterxml.jackson..`, `org.apache.kafka..`, `io.r2dbc..`, or `reactor.core..`; and `common` must not depend on Spring or any vendor library. Without them the module decays back into a coupled one within a release.

## Forbidden

| # | Pattern | Why |
|---|---|---|
| 1 | A vendor import in `application/` | Wrapping the dependency only at the import site defeats the point |
| 2 | `common/` depending on Spring or a vendor library | `common/` becomes the coupling it was built to remove |
| 3 | Domain entities in `common/` | Domain belongs in `domain/` |
| 4 | Several `common-*` modules | One `common/` with sub-packages; split only when the boundaries are stable |
| 5 | Abstracting with no second implementation and no test pain yet | YAGNI — wait for the second consumer |
