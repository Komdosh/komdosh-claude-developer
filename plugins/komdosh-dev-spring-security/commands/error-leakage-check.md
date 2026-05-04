# /error-leakage-check

Audit every `@ExceptionHandler` and `WebExceptionHandler` against the RFC 9457 contract. Flag stack traces in response bodies, raw exception messages on catch-all handlers, SQL state from jOOQ exceptions, persistence-id exposure, and missing correlation ids on 5xx.

Narrow scope of `/security-audit`. Use this after touching error-handling code.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if not already run. Refuse on library track.

- [ ] **Step 2: Invoke `security-auditor` with `--scope=error-leakage`**

The agent runs `check-error-leakage`, applies severity classification per `rules/security-audit.md`.

- [ ] **Step 3: Print findings**

Group by severity:

```
== BLOCKERS (3) ==

1. adapters/inbound/error/GlobalExceptionHandler.kt:48 — catch-all Exception handler:
   - Returns Map<String, Any>, not ProblemDetail.
   - Includes ex.message verbatim (rule 3).
   - Includes ex.stackTraceToString() (rule 4).

2. adapters/inbound/error/JpaExceptionHandler.kt:22 — DataAccessException handler:
   - Body includes ex.sqlState (rule 5).

3. (no catch-all Exception handler exists — uncaught exceptions surface as Spring default)

== WARNINGS (2) ==

1. adapters/inbound/error/GlobalExceptionHandler.kt:48 — no correlationId on 5xx (rule 7).
2. adapters/inbound/orders/OrderExceptionHandler.kt:31 — body includes order.id (rule 6, may be intentional).
```

- [ ] **Step 4: Suggest fixes**

For each BLOCKER:

| Pattern | Recommended remediation |
|---|---|
| Returns Map / String instead of ProblemDetail | `core/cleanuper` — mechanical conversion. Provide the file:line list. |
| Catch-all leaks ex.message or stack trace | Mechanical fix. Replace with: `ProblemDetail.forStatusAndDetail(INTERNAL_SERVER_ERROR, "An unexpected error occurred").also { it.setProperty("correlationId", correlationId) }`. |
| No catch-all Exception handler exists | `core/security-expert` — add a `@RestControllerAdvice` with `@ExceptionHandler(Exception::class)` mapping to 500 with correlation id. |
| SQL state / constraint name leak | `core/cleanuper` — strip the field. If the handler builds the body via concat, route to `core/security-expert` for redesign. |

- [ ] **Step 5: Write the report**

Output: `docs/security/error-leakage-YYYY-MM-DD.md`.
