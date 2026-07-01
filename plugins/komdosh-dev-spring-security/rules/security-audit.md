# Security Audit Rules

These rules define **what counts** for the three audit categories. Every finding the auditor surfaces must trace to one of these categorical rules.

## Severity classification

| Severity | Definition | Examples |
|---|---|---|
| **BLOCKER** | Production-impacting if shipped. The audit recommends fixing before release. | Unauthenticated public endpoint that exposes user data; stack trace leaked in 500 response; JWT algorithm allowlist permits `none`. |
| **WARNING** | Probable misconfiguration; ship with risk. | A `permitAll()` on a route that has no documented rationale; error response includes a persistence ID; JWK source has no refresh policy and the issuer's keys rotate quarterly. |
| **INFO** | Worth knowing, not blocking. | A route is unauthenticated but the controller handler is annotated `// PUBLIC: ...`; a deprecated authorization expression is in use but still works. |

## Auth audit (route ↔ SecurityWebFilterChain)

Every `@RestController` handler is matched against the project's filter chain. A handler is classified as one of:

| Class | Definition | Default severity |
|---|---|---|
| **Authenticated** | At least one filter rule explicitly authorizes the route (`hasRole`, `hasAuthority`, `authenticated()`, custom expression). | n/a (correct posture). |
| **Permit-all by rule** | A filter rule explicitly does `permitAll()` for the route. | INFO (note in report); WARNING if no rationale comment, ADR, or `// PUBLIC: ...` annotation accompanies the rule. |
| **Unmatched** | No filter rule matches the route at all → Spring's default behaviour applies (which depends on the chain's terminal rule). | BLOCKER if the terminal rule is `permitAll()` or absent (= unauthenticated by default); WARNING if the terminal rule is `authenticated()` (= authenticated by default, but the explicit-rule absence is a maintenance hazard). |
| **Shadowed** | Multiple rules match the same route; an earlier `permitAll()` shadows a later restrictive rule. | BLOCKER (Spring evaluates rules in order; the later rule never fires). |

The audit reports the **complete coverage matrix** — every handler × the rule that matched it (or "unmatched"). The report links to the controller file:line and the filter-chain config file:line.

## Error-leakage audit (RFC 9457)

Every `@ExceptionHandler` and `WebExceptionHandler` implementation must:

| Rule | Severity if violated |
|---|---|
| Return `application/problem+json` (or `ProblemDetail`) for non-2xx responses. | BLOCKER if returning raw `String` or generic JSON. |
| Never include the exception message verbatim if the exception's class is unhandled (catch-all `Exception` → must use a generic "An unexpected error occurred" + correlation id). | BLOCKER. |
| Never include stack traces in any profile (not just prod — `application-dev.yaml` doesn't make leakage acceptable). | BLOCKER. |
| Never include SQL state, jOOQ `DataAccessException` details, or constraint names. | BLOCKER. |
| Never include persistence IDs (database row ids, internal UUIDs not exposed in the public API). | WARNING (may be intentional if the IDs *are* the public contract). |
| Include a correlation id (from `X-Correlation-Id` request header or generated at ingress) on 5xx responses. | WARNING if missing. |
| Map the unhandled `Exception` catch-all to 500 — never let an uncaught exception fall through to Spring's default handler in production profiles. | BLOCKER. |

In the audit report, every finding cites the file:line of the handler and the rule it violated.

## JWT/JWK rotation audit

Applies only when the project uses `spring-boot-starter-oauth2-resource-server` or equivalent JWT decoding.

| Rule | Severity if violated |
|---|---|
| `ReactiveJwtDecoder` (or `NimbusReactiveJwtDecoder`) is configured. | BLOCKER if missing in a project that handles authenticated requests. |
| Algorithm allowlist excludes `none`. | BLOCKER. (`none` accepts any token unverified.) |
| For asymmetric verification (the common case), allowlist excludes `HS256` / `HS384` / `HS512` symmetric algorithms. | WARNING if symmetric is included alongside asymmetric — possible algorithm-confusion attack surface. |
| JWK source has a documented refresh policy: either `JwkSetUriReactiveJwtDecoderBuilder` with a non-default cache TTL, or a refresh interval set explicitly. | WARNING. |
| Test fixtures (under `src/test/`) do NOT reuse production-shaped keys. Test JWTs MUST be signed with throwaway keys local to the test. | WARNING. |
| Issuer (`iss` claim) and audience (`aud` claim) are validated, not just the signature. | BLOCKER if missing — a token signed by the right key but issued for a different audience must be rejected. |
| Token expiration (`exp`) is enforced (the default in `ReactiveJwtDecoder`, but custom decoders may opt out). | BLOCKER if a custom decoder skips it. |

## PII-exposure audit

Personal data (email, phone, name, address, national ID, precise location, financial, health) leaking out of a service is a data-protection incident, not just untidiness. This audit is Spring-aware — it inspects logging, `@ExceptionHandler` bodies, response DTOs, event serializers, and observability calls — which is exactly what a generic secret/CVE scanner cannot do. It complements `check-error-leakage` (which is about RFC 9457 hygiene generally); here the lens is specifically personal data. Findings trace to `core/rules/pii-handling.md`.

| Rule | Severity if violated |
|---|---|
| Raw PII (a personal-data field's value, or `.value` of a PII value class) interpolated into a `log.*` / `throw` message, in **any** profile. | BLOCKER. Logs are not access-controlled or residency-bound like the DB. |
| PII in a span attribute (`setAttribute`), metric tag, or `MDC.put`. | BLOCKER (leak) — and MDC in a coroutine/WebFlux path is also unsafe. |
| PII returned in an error response body (`ProblemDetail` detail/properties built from a `User`, email, etc.). | BLOCKER. |
| Unmasked PII in a response DTO beyond what the caller is entitled to (raw email/phone/PAN where a masked form suffices). | WARNING (BLOCKER if it exposes another subject's data). |
| PII embedded in an event/Avro payload without a documented justification (a tokenised reference was possible). | WARNING. |
| A PII-bearing `value class` / `data class` without a redacting `toString()` (every log of the enclosing object leaks it). | WARNING. |
| No demonstrable erasure/access path for a subject's PII (right-to-erasure / access can't be honoured mechanically). | WARNING (INFO if out of the diff's scope but worth noting). |

The audit reports each finding with the file:line and the PII field, and — like every other category — **never prints the personal-data value**. Storage/residency/retention obligations (encryption at rest, 152-FZ localization, backup erasure) are the infra suite's `data-protection-auditor`; this category is the application's data-in-motion surface.

## Anti-patterns the audit explicitly does NOT flag

The audit is opinionated about what's worth a developer's attention. These are explicitly **not** flagged:

- **Generic CVE matches.** Spring Security CVE feeds are commodity tooling; the audit assumes a separate dependency-update flow handles them. Use `kotlin-extras/dependency-upgrader` (`/upgrade`) for CVE patches.
- **Secret-scan over commits.** Use gitleaks / trufflehog as commodity pre-commit hooks; not in scope.
- **TLS configuration.** Owned by the deploy platform / ingress; out of service-level scope.
- **Rate limiting.** Owned by the gateway / Spring Cloud Gateway / API Gateway; out of service-level scope.
- **CORS configuration.** Important but well-served by Spring's defaults + a single config file; an audit adds little.

Adding any of these would diffuse the plugin's scope. Keep it Spring-Security-shaped or a separate audit plugin altogether.
