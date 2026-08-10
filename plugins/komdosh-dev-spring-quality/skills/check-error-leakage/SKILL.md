---
name: check-error-leakage
user-invocable: false
description: "Audits @ExceptionHandler and WebExceptionHandler implementations for RFC 9457 hygiene. Detects raw-string responses, stack-trace leakage, SQL state from jOOQ exceptions, persistence-id exposure, missing correlation ids on 5xx, and missing catch-all Exception → 500 mapping. Read-only — surfaces findings with file:line and the rule violated."
---

# Check Error Leakage

## When to Use

Run this skill from `/error-leakage-check` or as part of `/security-audit`. It enumerates every error handler in the project and checks each against the RFC 9457 contract from `core/rules/error-handling.md` (extended with security-specific patterns from `rules/security-audit.md`).

Read-only. Output is a structured list of findings.

## Do NOT

- Compile or run code. The skill does static parsing only.
- Treat handlers in test sources as production handlers — only `src/main/` counts.
- Assume that a handler returning `ProblemDetail` is automatically safe; check the body it constructs for leaks.

## Steps

- [ ] **Step 1: Locate every error handler**

Three shapes coexist in WebFlux projects; search for all three:

```bash
# 1. @ExceptionHandler methods on @RestControllerAdvice / @ControllerAdvice classes
grep -rn '@ExceptionHandler\b' --include='*.kt' \
  --exclude-dir=build --exclude-dir=test src/main 2>/dev/null

# 2. WebExceptionHandler implementations (functional/global)
grep -rln 'WebExceptionHandler\b\|: WebExceptionHandler' --include='*.kt' \
  --exclude-dir=build --exclude-dir=test src/main 2>/dev/null

# 3. ErrorWebExceptionHandler subclasses
grep -rln 'ErrorWebExceptionHandler\b' --include='*.kt' \
  --exclude-dir=build --exclude-dir=test src/main 2>/dev/null
```

If zero handlers exist AND the project has `@RestController` annotations, surface a BLOCKER candidate to the calling agent: "no exception handlers detected — uncaught exceptions may surface as default Spring 500 with the full message."

- [ ] **Step 2: For each handler, capture its shape**

For each handler function found in Step 1, record:

- The exception type(s) it handles (from `@ExceptionHandler(SomeException::class)` or the dispatch logic in a `WebExceptionHandler`)
- The HTTP status it returns (from `@ResponseStatus`, the `HttpStatus.X` literal, or the `ServerHttpResponse.statusCode` setter)
- The body type it returns (`ProblemDetail`, `String`, custom DTO, `Mono<...>`, etc.)
- A snippet of the body construction (read 5–10 lines around the return)

- [ ] **Step 3: Apply each rule to each handler**

For each handler, run these checks. Each check that fails becomes a finding.

| # | Check | File-pattern signal |
|---|---|---|
| 1 | Returns `application/problem+json` (`ProblemDetail`) for non-2xx, not raw `String` or generic `Map`. | Look for `ProblemDetail.forStatus...` or `ResponseEntity<ProblemDetail>` in return path. Raw `String` or `Map<String, Any>` is a finding. |
| 2 | Catch-all `Exception` handler exists AND maps to 500. | Search for `@ExceptionHandler(Exception::class)` (or `Throwable::class`). If absent in any `*ControllerAdvice.kt`, it's a finding. |
| 3 | Body does NOT include `ex.message` directly when the exception class is `Exception` or `Throwable`. | Grep within the catch-all handler body for `ex\.message` / `it\.message` / `throwable\.message`. Generic exceptions must use a static "An unexpected error occurred" message. |
| 4 | Body does NOT include the stack trace. | Grep for `ex.stackTrace`, `printStackTrace`, `ex.toString()` (which includes class name + message), or `ExceptionUtils.getStackTrace`. Any of these in a handler body is a finding. |
| 5 | Body does NOT include SQL state or jOOQ-specific fields. | Grep for `DataAccessException`, `SQLException`, `ex.sqlState`, `getCause()` chains that surface DB info. |
| 6 | Body does NOT include persistence IDs (heuristic: a UUID, Long, or `OrderId`/`UserId`-shaped type literal in the body). | Look for direct UUIDs/IDs in the response builder. WARNING (may be intentional). |
| 7 | 5xx responses include a correlation id. | Look for `setProperty("correlationId", ...)` or `correlationId` field set on the body. WARNING if missing. |

For each finding, record:
- The rule number and short description
- File:line of the offending handler
- A short snippet showing the violation

- [ ] **Step 4: Cross-check for handler reachability**

A handler that exists but is **shadowed** by a more general one (e.g. `@ExceptionHandler(Exception::class)` declared above `@ExceptionHandler(EntityNotFoundException::class)` in the same `@RestControllerAdvice`) won't fire. Spring resolves to the most specific handler regardless of declaration order, but Kotlin's class hierarchy makes this nuanced. Note (INFO) when two handlers in the same advice could plausibly match the same exception.

- [ ] **Step 5: Emit findings**

```json
{
  "service": "<service-name>",
  "handlers_scanned": 8,
  "handlers": [
    {
      "file":         "adapters/inbound/error/GlobalExceptionHandler.kt:24",
      "handles":      "EntityNotFoundException",
      "status":       404,
      "body_type":    "ProblemDetail",
      "findings":     []
    },
    {
      "file":         "adapters/inbound/error/GlobalExceptionHandler.kt:48",
      "handles":      "Exception",
      "status":       500,
      "body_type":    "Map<String, Any>",
      "findings": [
        {
          "rule":     1,
          "severity": "BLOCKER",
          "message":  "returns Map<String, Any>, not ProblemDetail",
          "snippet":  "return mapOf(\"error\" to ex.message, \"trace\" to ex.stackTraceToString())"
        },
        {
          "rule":     3,
          "severity": "BLOCKER",
          "message":  "catch-all Exception body includes ex.message verbatim"
        },
        {
          "rule":     4,
          "severity": "BLOCKER",
          "message":  "body includes ex.stackTraceToString()"
        },
        {
          "rule":     7,
          "severity": "WARNING",
          "message":  "no correlation id on 5xx response"
        }
      ]
    }
  ],
  "global_findings": [
    {
      "rule":     2,
      "severity": "INFO",
      "message":  "catch-all Exception handler exists and maps to 500"
    }
  ]
}
```

If no `@ExceptionHandler(Exception::class)` exists AT ALL, add a top-level BLOCKER finding: "no catch-all Exception handler — uncaught exceptions fall through to Spring's default error response, which may leak internals."

## Output

The JSON above + a markdown summary the calling agent embeds in the final report.

## Notes

- The skill recognises `org.springframework.http.ProblemDetail` (Spring 6+) and the older `Map`-based custom problem responses. Custom ProblemDetail-shaped types are accepted iff they expose `setProperty(...)` or equivalent (look for the body-builder pattern).
- For projects using kotlinx-coroutines `suspend fun` exception handlers, the skill recognises both `suspend` and reactive (`Mono.error`) shapes.
- The skill does NOT execute the handler to see what it would return — pure static parse. A handler that builds the body via reflection is reported as INFO ("body construction is dynamic; manual review recommended").
