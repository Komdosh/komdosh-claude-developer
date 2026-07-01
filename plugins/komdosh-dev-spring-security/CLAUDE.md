# CLAUDE.md — komdosh-dev-spring-security

Defensive security audits on top of `komdosh-dev-spring-core`. Spring-specific by design — generic security tooling (gitleaks, dependency CVE scanning, secret detection in commits) is commodity and not plugin-shaped; this plugin focuses on what only a Spring-aware reviewer can find.

## What it adds

| Command | Skill | What it does |
|---|---|---|
| [`/security-audit`](commands/security-audit.md) | composite | Runs all three sub-audits below. Aggregates findings into `docs/security/audit-<date>.md` with BLOCKER / WARNING / INFO classification + remediation per finding. |
| [`/auth-audit`](commands/auth-audit.md) | [`match-routes-to-filters`](skills/match-routes-to-filters/SKILL.md) | Parses every `@RestController` handler and matches it against the project's `SecurityWebFilterChain` config. Flags routes that match no authorization rule (= unauthenticated by default), routes that allow `permitAll()` but deal in sensitive resources, and route patterns that overlap (a permissive earlier rule shadowing a restrictive later one). |
| [`/error-leakage-check`](commands/error-leakage-check.md) | [`check-error-leakage`](skills/check-error-leakage/SKILL.md) | Audits `@ExceptionHandler` and `WebExceptionHandler` implementations for RFC 9457 hygiene. Flags handlers that return raw exception messages, leak stack traces in non-empty profiles, expose SQL state from JOOQ exceptions, or include persistence IDs in error bodies. Confirms unhandled `Exception` is mapped to a 500 with a correlation id only. |
| [`/jwt-rotation`](commands/jwt-rotation.md) | [`audit-jwt-rotation`](skills/audit-jwt-rotation/SKILL.md) | Checks JWT/JWK plumbing: that a `ReactiveJwtDecoder` is configured, that JWK source has a refresh interval (or fetches via JWK Set URI with the default cache), that the algorithm allowlist is restrictive (no `none`, no symmetric in a public-key context), and that test fixtures don't reuse production keys. |
| [`/pii-leakage-check`](commands/pii-leakage-check.md) | [`scan-pii-exposure`](skills/scan-pii-exposure/SKILL.md) | Audits the service's data-in-motion surface for personal-data (PII) exposure — raw PII in log/trace statements (any profile), PII in span attributes / metric tags / MDC, PII in `@ExceptionHandler`/`ProblemDetail` bodies, unmasked PII in response DTOs beyond entitlement, PII in event/Avro payloads without a tokenised alternative, and PII value classes without a redacting `toString()`. Classifies per the PII-exposure category in `rules/security-audit.md`; cites file:line + the PII field; never prints the value. |

Agent:

- [`security-auditor`](agents/security-auditor.md) — orchestrates the four sub-audits, classifies findings, writes the consolidated report. Read-only — never modifies code or config; never extracts secrets; never prints personal data; never invokes `/upgrade` or `/add-endpoint`. Recommends remediation by handing off to `core/security-expert` (writes new filters), `core/observability-expert` (adds correlation-id propagation if missing), or `core/cleanuper` (mechanical PII-log fixes per `core/rules/pii-handling.md`).

Rules:

- [`rules/security-audit.md`](rules/security-audit.md) — what counts as BLOCKER vs WARNING vs INFO per category; the canonical RFC 9457 leakage list; JWT algorithm allowlist; route-coverage rules.

## Boundary

This plugin **audits** existing security posture. It does NOT:

- Write new auth filters or rules — that's `core/security-expert` via the hand-off.
- Run dependency CVE scans — commodity tooling outside marketplace scope.
- Run gitleaks / secret-scan over commits — same.
- Manage actual secrets, keys, or credentials — never reads private keys; only verifies presence of configuration variables.
- Print any personal-data value found during the PII audit — findings are file:line + PII field only.
- Audit PII **at rest** (encryption, 152-FZ residency, backup erasure) — that's the infra suite's `komdosh-dev-infra-core` `/pii-audit`. This plugin's PII scope is the application's data-**in-motion** surface (logs, traces, error bodies, DTOs, events).
- Modify source files. Output is one Markdown report per audit + classification.

## Dependencies

Requires `komdosh-dev-spring-core`. Reads conventions from `core/rules/spring-webflux.md` and `core/rules/error-handling.md` (RFC 9457 contract). Hands off to:

- `core/security-expert` — to write or modify auth filters when the audit recommends a fix.
- `core/observability-expert` — when the audit surfaces missing correlation-id propagation in error responses.
- `core/adr-writer` — when the audit recommends a deliberately-broad `permitAll()` (an ADR documents the rationale).
- `core/cleanuper` — to align an existing `@ExceptionHandler` with RFC 9457 if the deviation is minor.

## When to run

- Before a release. The release plugin's `/release-prep` does NOT call this automatically; security audits are deeper than release readiness wants to be. Run `/security-audit` on its own cadence (every release for high-risk services, every quarter for steady-state services).
- After adding a new public endpoint group. `/auth-audit` only — the route↔filter coverage matrix is the highest-value check after surface changes.
- After an upstream Spring Security CVE that touches the abstractions in use. `/security-audit` to confirm the project's posture, then `core/extras/dependency-upgrader` (`/upgrade`) for the patch.

@rules/security-audit.md
