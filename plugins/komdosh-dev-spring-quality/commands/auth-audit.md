# /auth-audit [--module=<glob>]

Build the route ↔ `SecurityWebFilterChain` coverage matrix for every `@RestController` handler. Reports unauthenticated routes, permit-all rules without rationale, and shadowed rules.

Narrow scope of `/security-audit`. Use this directly after adding a new endpoint group when the full audit is overkill.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if not already run. Refuse on library track.

- [ ] **Step 2: Invoke `security-auditor` with `--scope=auth`**

The agent runs `match-routes-to-filters` and classifies each handler. Skips error-leakage and JWT sub-audits.

- [ ] **Step 3: Print the coverage matrix**

For the user, render the matrix as a table:

```
Method   Path                                    Class                  Rule (file:line)
─────────────────────────────────────────────────────────────────────────────────────────
POST     /api/v1/admin/users/{id}/promote        UNMATCHED              terminal=permitAll  ← BLOCKER
GET      /actuator/info                          permit-all-by-rule     SecurityConfig.kt:27 (// PUBLIC: ...)
POST     /api/v1/orders                          authenticated          SecurityConfig.kt:31
POST     /api/v1/legacy/import                   SHADOWED by ADMIN rule SecurityConfig.kt:25 → :33  ← BLOCKER
...
Total: 47 handlers. 41 authenticated · 4 permit-all · 1 unmatched · 1 shadowed.
```

- [ ] **Step 4: Suggest the fix path**

For each BLOCKER:

```
BLOCKER 1: POST /api/v1/admin/users/{id}/promote is unauthenticated.
Fix: invoke `core/backend-implementer` (per `core/rules/spring-security.md`) with this prompt:
  "Add a hasRole('ADMIN') rule for /api/v1/admin/** in SecurityConfig.kt:48
   before the terminal anyExchange().authenticated() (or anyExchange().permitAll())."
```

For each WARNING (e.g. unrationalized `permitAll`):

```
WARNING: GET /api/v1/health is permit-all but has no // PUBLIC: rationale comment.
Fix options:
  - Annotate the controller method with `// PUBLIC: <rationale>` (small).
  - Open an ADR documenting the rationale (`/adr-new`).
  - Tighten the rule to authenticated() if the route shouldn't be public.
```

- [ ] **Step 5: Write the matrix to disk**

Output: `docs/security/auth-audit-YYYY-MM-DD.md` (a focused subset of the full audit report).
