# Code Style Rules

## Data Classes

Prefer `data class` with `val` fields for immutable value objects, commands, and events:

```kotlin
data class CreateOrderCommand(
    val customerId: CustomerId,
    val items: List<OrderItem>,
    val deliveryAddress: Address
)
```

Use `var` only when mutation is genuinely necessary.

## Value Classes

`@JvmInline value class` for every domain identifier and typed primitive. Zero runtime overhead. See `rules/domain-purity.md` for examples.

## Sealed Hierarchies

Use `sealed interface` for result types, discriminated unions, and command hierarchies:

```kotlin
sealed interface PaymentResult {
    data class Authorised(val transactionId: TransactionId) : PaymentResult
    data object InsufficientFunds : PaymentResult
    data class Failed(val reason: String) : PaymentResult
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Class / interface | PascalCase | `OrderService`, `PaymentResult` |
| Function / property | camelCase | `findById`, `customerId` |
| Constant | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| File | PascalCase.kt matching primary class | `OrderService.kt` |
| Test class | `<Subject>Test.kt` | `OrderServiceTest.kt` |
| Package | lowercase, dot-separated | `com.example.orders.domain` |

## File Size

A file over ~300 lines is a signal to split by responsibility. Extension functions for a type can move to `<Type>Extensions.kt`.

## Nullability

- Prefer non-null types everywhere. Use `?` at system boundaries (user input, external API responses).
- Never use `!!` in production code — handle nulls explicitly:
  - `?: throw EntityNotFoundException(id)` when absence is a domain error
  - `?.let { ... }` for optional processing
  - `?: return` for early exits

## Companion Objects

Use companion objects only for factory methods and constants. Don't use them as utility namespaces.

## No Magic Numbers

Extract numeric literals to named constants in a companion object:

```kotlin
companion object {
    private const val MAX_ITEMS_PER_ORDER = 100
    private val PROCESSING_TIMEOUT = Duration.ofSeconds(30)
}
```
