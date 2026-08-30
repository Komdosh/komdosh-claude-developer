# Security Audit Rules

What counts as a finding, and at what severity. Every finding traces to a rule here.

| Severity | Meaning |
|---|---|
| **BLOCKER** | Production-impacting if shipped — fix before release |
| **WARNING** | Probable misconfiguration; shipping carries risk |
| **INFO** | Worth knowing, not blocking |

## Auth — route ↔ SecurityWebFilterChain

Every `@RestController` handler is classified against the chain, and the report is the **complete coverage matrix** — every handler × the rule that matched it — citing both the handler and the filter-rule `file:line`.

| Class | Severity |
|---|---|
| **Authenticated** — a rule explicitly authorizes the route | correct posture |
| **Permit-all by rule** | INFO; **WARNING when no rationale** (comment, ADR, or `// PUBLIC:` marker) accompanies it |
| **Unmatched** — no rule matches, so the chain's terminal rule decides | **BLOCKER** when the terminal rule is `permitAll()` or absent; WARNING when it is `authenticated()` — right posture, but the missing explicit rule is a maintenance hazard |
| **Shadowed** — an earlier `permitAll()` matches first, so a later restrictive rule never fires | **BLOCKER** |

Unmatched routes are the endpoints nobody knows are open. That is the finding this audit exists for.

## Error leakage (RFC 9457)

| Rule | Severity |
|---|---|
| Non-2xx returns `ProblemDetail` / `application/problem+json`, not a raw `String` or ad-hoc JSON | BLOCKER |
| A catch-all `Exception` → 500 handler exists — nothing falls through to the container default | BLOCKER |
| The catch-all returns a generic message + correlation ID, never the exception message verbatim | BLOCKER |
| No stack traces — **in any profile**; a dev profile does not make leakage acceptable | BLOCKER |
| No SQL state, jOOQ `DataAccessException` detail, or constraint names | BLOCKER |
| No persistence IDs | WARNING — may be intentional when the IDs *are* the public contract |
| Correlation ID present on 5xx | WARNING |

## JWT / JWK rotation

Applies only where the project decodes JWTs (`spring-boot-starter-oauth2-resource-server` or equivalent).

| Rule | Severity |
|---|---|
| A `ReactiveJwtDecoder` is configured | BLOCKER if absent in a service handling authenticated requests |
| Algorithm allowlist excludes `none` | BLOCKER — `none` accepts any token unverified |
| **Issuer and audience are validated, not just the signature** | BLOCKER — a token signed by the right key but issued for another audience must be rejected |
| Expiration enforced | BLOCKER if a custom decoder opts out |
| Symmetric algorithms not allowlisted alongside asymmetric | WARNING — algorithm-confusion surface |
| JWK source has an explicit refresh policy | WARNING |
| Test fixtures use throwaway keys, never production-shaped ones | WARNING |

Never read or print key material.

## PII exposure

The application's **data-in-motion** surface — logging, `@ExceptionHandler` bodies, response DTOs, event serializers, observability calls. Spring-aware in a way no generic secret or CVE scanner is. Criteria and severities are `core/rules/pii-handling.md`, executed by `core/pii-safety-scan` at `depth=audit`; storage and residency are the infra suite's `data-protection-auditor`.

Every finding cites `file:line` and the field. **Never the value.**

## Deliberately out of scope

Not flagged, so the audit stays sharp:

- **Generic CVE matches** — commodity tooling; use `/upgrade` (`kotlin-extras`) for CVE patches.
- **Secret scanning over commits** — gitleaks/trufflehog as pre-commit hooks.
- **TLS, rate limiting, CORS** — owned by the deploy platform, the gateway, and Spring's defaults respectively.

Adding any of these diffuses the plugin's scope. Keep it Spring-Security-shaped, or make it a separate plugin.
