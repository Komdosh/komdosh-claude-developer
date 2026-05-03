# Error Handling Rules

## All Errors Use `application/problem+json` (RFC 9457)

Every non-2xx response must be `application/problem+json`. Never return raw strings, HTML, or generic JSON objects for errors.

```kotlin
// Spring 6+ has built-in ProblemDetail support
@ExceptionHandler(EntityNotFoundException::class)
@ResponseStatus(HttpStatus.NOT_FOUND)
fun handleNotFound(ex: EntityNotFoundException, request: ServerWebExchange): ProblemDetail =
    ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Resource not found")
        .also { it.instance = request.request.uri }
```

## HTTP Status Semantics

| Error family | Status | When to use |
|---|---|---|
| Not found | 404 | Resource identified by the request does not exist |
| Invalid input | 400 | Malformed request body, constraint violation, missing required field |
| Auth missing | 401 | No valid credentials presented |
| Auth insufficient | 403 | Valid credentials but lacking required role/scope |
| Conflict | 409 | Optimistic lock failure, duplicate resource, state conflict |
| Unexpected | 500 | Anything not caught by the above |

## No Internal Detail Leaks

- Never include stack traces, SQL, class names, or internal IDs in response bodies.
- Map all unhandled exceptions to 500 with a correlation ID only:

```kotlin
@ExceptionHandler(Exception::class)
@ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
fun handleUnexpected(ex: Exception, exchange: ServerWebExchange): ProblemDetail {
    val correlationId = exchange.request.headers.getFirst("X-Correlation-Id") ?: UUID.randomUUID().toString()
    log.error("Unhandled exception [correlationId=$correlationId]", ex)
    return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred")
        .also { it.setProperty("correlationId", correlationId) }
}
```

## Domain Exception Hierarchy

Define domain exceptions in `domain/exceptions/`:

```kotlin
sealed class DomainException(message: String) : RuntimeException(message)
class EntityNotFoundException(val id: String) : DomainException("Entity not found: $id")
class ConflictException(message: String) : DomainException(message)
class ValidationException(message: String) : DomainException(message)
```

Map to HTTP in `adapters/inbound/` exception handlers. Domain exceptions must not import Spring.
