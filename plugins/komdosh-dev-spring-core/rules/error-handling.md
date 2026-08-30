# Error Handling

- **Every non-2xx response is `application/problem+json`** (RFC 9457, via Spring's `ProblemDetail`). Never a raw string, HTML, or an ad-hoc JSON shape — including on 401/403, where the Spring defaults return an empty body.
- **A catch-all `@ExceptionHandler(Exception::class)` → 500 must exist.** Without it, the container's default page leaks the stack trace.
- A 5xx body carries a correlation ID and nothing else. **Never a stack trace, SQL, jOOQ exception text, class name, or persistence ID** — log those, don't serialize them.
- Domain exceptions: a `sealed class DomainException` hierarchy in `domain/exceptions/`, with **no Spring imports**. Adapters map them to status codes.

409 is the one that gets missed: optimistic-lock failure, duplicate resource, and state conflict are not 400.
