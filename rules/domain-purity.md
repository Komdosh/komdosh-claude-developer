# Domain Purity Rules

## Forbidden Imports in `domain/` and `application/`

These packages must **never** appear in `domain/` or `application/` source files:

- `org.springframework.*` (exception: `application/` may use `@Transactional` — but see `rules/persistence.md` for why you shouldn't)
- `org.jooq.*`
- `org.apache.kafka.*`
- `io.r2dbc.*`
- `com.fasterxml.jackson.*`
- `jakarta.persistence.*`

If serialization is needed in the domain, define a marker interface in `domain/` and implement it in `adapters/`.

## Value Classes for Domain Primitives

Use `@JvmInline value class` for all domain identifiers and typed primitives. Zero runtime overhead. Compile-time safety against mixing up IDs.

```kotlin
@JvmInline
value class OrderId(val value: UUID)

@JvmInline
value class CustomerId(val value: UUID)

@JvmInline
value class EmailAddress(val value: String) {
    init { require(value.contains('@')) { "Invalid email address: $value" } }
}

@JvmInline
value class Money(val cents: Long) {
    init { require(cents >= 0) { "Money cannot be negative" } }
}
```

This prevents `findById(customerId)` from accidentally accepting an `OrderId`.

## Domain Model Defaults

- Prefer `data class` for value objects, commands, and events — immutable by default.
- Prefer `sealed class` / `sealed interface` for result types and discriminated unions.
- Use a domain-specific sealed result for error signaling — never throw from the domain model.
- Keep domain entities free of framework annotations.

```kotlin
sealed interface OrderResult {
    data class Success(val order: Order) : OrderResult
    data class InsufficientStock(val available: Int) : OrderResult
    data class CustomerNotFound(val customerId: CustomerId) : OrderResult
}
```
