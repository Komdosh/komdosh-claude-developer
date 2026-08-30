# Domain Purity

## Banned imports in `domain/` and `application/`

`org.springframework.*` · `org.jooq.*` · `org.apache.kafka.*` · `io.r2dbc.*` · `com.fasterxml.jackson.*` · `jakarta.persistence.*`

Sole exception: `application/` may use `@Transactional` — but see `rules/persistence.md`, which says not to. If the domain needs serialization, declare a marker interface in `domain/` and implement it in an adapter.

`module-boundary-check` greps these.

## Typed identifiers

Every domain identifier and typed primitive is a `@JvmInline value class` with its invariant in `init`. This is what stops `findById(customerId)` from compiling when it wants an `OrderId`.

## Errors

The domain signals failure with a sealed result type, not by throwing. Domain entities carry no framework annotations.
