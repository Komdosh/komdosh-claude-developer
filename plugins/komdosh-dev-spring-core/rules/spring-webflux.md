# Spring WebFlux Rules

## Controllers Must Use `suspend fun`

Every controller handler function must be `suspend fun`. Never return `Mono<T>` or `Flux<T>` from a controller.

```kotlin
// CORRECT
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(private val orderService: OrderService) {

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    suspend fun create(@Valid @RequestBody request: CreateOrderRequest): OrderResponse =
        orderService.create(request.toCommand()).toResponse()

    @GetMapping("/{id}")
    suspend fun findById(@PathVariable id: UUID): OrderResponse =
        orderService.findById(OrderId(id))?.toResponse()
            ?: throw EntityNotFoundException(id.toString())
}

// WRONG — never return Mono/Flux from a controller
@PostMapping
fun create(@RequestBody request: CreateOrderRequest): Mono<OrderResponse> = ...
```

## No Business Logic in Controllers

Controllers are adapter layer only: deserialize → validate → delegate → serialize.
Business rules, domain logic, and orchestration belong in `application/` services.

## Context Propagation Before `withContext`

Extract auth principal, correlation ID, and OTel trace context **before** any `withContext(Dispatchers.IO)` call:

```kotlin
@GetMapping("/me/orders")
suspend fun myOrders(): List<OrderResponse> {
    // Extract BEFORE withContext
    val auth = ReactiveSecurityContextHolder.getContext().awaitSingle().authentication
    val userId = UserId(auth.name)
    return orderService.findByUser(userId).map { it.toResponse() }
}
```

## Error Handling

- All exceptions propagate via `@ExceptionHandler` methods or a `WebExceptionHandler`.
- Map to `application/problem+json` at the handler layer — never return raw exception messages.
- See `rules/error-handling.md` for HTTP status semantics.

## Request Validation

Use Jakarta Bean Validation (`@Valid`) on request bodies. Validation errors surface as 400 via Spring's default handler or a custom `@ExceptionHandler(MethodArgumentNotValidException::class)`.
