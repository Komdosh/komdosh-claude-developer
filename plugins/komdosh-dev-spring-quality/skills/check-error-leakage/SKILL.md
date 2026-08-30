---
name: check-error-leakage
user-invocable: false
description: "Audits @ExceptionHandler and WebExceptionHandler implementations for RFC 9457 hygiene. Detects raw-string responses, stack-trace leakage, SQL state from jOOQ exceptions, persistence-id exposure, missing correlation ids on 5xx, and missing catch-all Exception → 500 mapping. Read-only — surfaces findings with file:line and the rule violated."
---

# Check Error Leakage

Enumerates every error handler and checks it against `core/rules/error-handling.md` plus the security-specific patterns in `rules/security-audit.md`. Static parse only — never compile or run.

**Only `src/main/` counts.** And a handler returning `ProblemDetail` is not automatically safe — what matters is the body it builds.

## 1. Find every handler

Three shapes coexist in WebFlux and all three must be searched: `@ExceptionHandler` methods on `@(Rest)ControllerAdvice`, `WebExceptionHandler` implementations, and `ErrorWebExceptionHandler` subclasses.

**Zero handlers plus any `@RestController` is itself a top-level BLOCKER** — uncaught exceptions then surface through Spring's default error response.

Per handler, record the exception types handled, the status returned, the body type, and the body construction.

## 2. Checks

| # | Check | Signal | Severity |
|---|---|---|---|
| 1 | Non-2xx returns `ProblemDetail`, not raw `String`/`Map` | body type in the return path | BLOCKER |
| 2 | A catch-all `Exception`/`Throwable` → 500 handler exists | `@ExceptionHandler(Exception::class)` anywhere | BLOCKER if absent |
| 3 | The catch-all does **not** include `ex.message` verbatim | `ex.message`, `it.message`, `throwable.message` in that body | BLOCKER |
| 4 | No stack trace | `stackTrace`, `printStackTrace`, `ExceptionUtils.getStackTrace`, **`ex.toString()`** — which carries class name and message | BLOCKER |
| 5 | No SQL state or jOOQ detail | `sqlState`, `DataAccessException` fields, `getCause()` chains surfacing DB info | BLOCKER |
| 6 | No persistence IDs | UUID/id-shaped values in the body builder | WARNING — may be intentional |
| 7 | Correlation ID on 5xx | `setProperty("correlationId", …)` or equivalent | WARNING |

## 3. Reachability

Two handlers in one advice that could both match the same exception is an INFO. Spring resolves to the most specific handler regardless of declaration order, but Kotlin's hierarchy makes the "most specific" call non-obvious, so it is worth a human's eye rather than a verdict.

## 4. Emit

JSON: `handlers_scanned`, a per-handler record (`file:line`, exceptions handled, status, body type, findings with rule / severity / message / snippet), and `global_findings` for the whole-project checks. Plus a markdown summary for the calling agent.

Recognise both Spring 6's `ProblemDetail` and older `Map`-shaped problem responses, and both `suspend` and `Mono.error` handler shapes. A handler that builds its body dynamically (reflection) is INFO — "manual review recommended", not a pass.
