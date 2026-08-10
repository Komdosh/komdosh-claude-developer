# CLAUDE.md — komdosh-dev-spring-quality

The audit and QA-artifact suite on top of `komdosh-dev-spring-core`. One theme: **find out what's actually true about a finished service** — is it secure, is it leaking personal data, is it coupled to a vendor it shouldn't be, and can a human exercise it by hand.

Everything here is read-only except the QA writers, which only ever write under `docs/qa/`.

## What it adds

### Security & data-protection audits

| Command | Backed by | What it checks |
|---|---|---|
| [`/security-audit`](commands/security-audit.md) | [`security-auditor`](agents/security-auditor.md) | Composite: runs all four audits below in sequence and aggregates into `docs/security/audit-<date>.md`, classified BLOCKER/WARNING/INFO. |
| [`/auth-audit`](commands/auth-audit.md) | [`match-routes-to-filters`](skills/match-routes-to-filters/SKILL.md) | Every `@RestController` handler vs every `SecurityWebFilterChain` rule — classifies each as authenticated / permit-all-by-rule / **unmatched** / **shadowed**. The unmatched ones are the endpoints nobody knows are open. |
| [`/error-leakage-check`](commands/error-leakage-check.md) | [`check-error-leakage`](skills/check-error-leakage/SKILL.md) | RFC 9457 hygiene — raw-string responses, stack traces, jOOQ SQL state, persistence IDs, missing correlation id on 5xx, missing catch-all `Exception` → 500. |
| [`/jwt-rotation`](commands/jwt-rotation.md) | [`audit-jwt-rotation`](skills/audit-jwt-rotation/SKILL.md) | `ReactiveJwtDecoder` present, algorithm allowlist excludes `none` and prevents confusion, JWK refresh policy, issuer + audience validation, no prod keys in test fixtures. Never reads key material. |
| [`/pii-leakage-check`](commands/pii-leakage-check.md) | core's `pii-safety-scan` at `depth=audit` | Personal data on the data-in-motion surface — logs, traces, metric tags, MDC, error bodies, response DTOs, event payloads, un-redacted PII value classes, subject-rights reachability. |

The PII scan lives in **core**, not here, and takes a `depth` parameter. There was previously a near-identical copy in each plugin; depth is a parameter, not a plugin boundary, and two copies of one lexicon drift.

### Vendor decoupling

| Command | Agent | What it does |
|---|---|---|
| [`/audit-leaks`](commands/audit-leaks.md) | [`platform-developer`](agents/platform-developer.md) | Finds concrete vendor types (Micrometer, jOOQ, Reactor, Jackson, Kafka client, R2DBC, Spring beyond `@Service`/`@Transactional`) referenced from `application/` and `domain/`, proposes abstractions, and stages them into a leaf `common/` module. Audit mode reports; extract mode refactors. |

### QA artifacts

| Command | Writers | Output |
|---|---|---|
| [`/qa [plan\|postman\|console\|all]`](commands/qa.md) | [`qa-plan-writer`](agents/qa-plan-writer.md) · [`qa-postman-writer`](agents/qa-postman-writer.md) · [`qa-console-writer`](agents/qa-console-writer.md) | `docs/qa/manual-validation-plan.md` (markdown checklist, checked boxes preserved by step id across regenerations) · `docs/qa/postman/` (v2.1 collection with `pm.test` assertions and chained variables, plus per-env files, Newman-runnable) · `docs/qa/qa-console.html` (single self-contained file, inline CSS + vanilla JS, no CDN, no build step, opens from `file://`) |

One command, three writers, **one** [`discover-api-surface`](skills/discover-api-surface/SKILL.md) pass. Three separate commands rediscovered the surface three times and could produce three artifacts describing three different snapshots of the API. The writers stay separate because their output specs genuinely differ — a markdown checklist, a Postman JSON schema, and an HTML application share their inputs, not their bodies — and `all` runs them in parallel over disjoint paths.

## Boundary

- **Audits, never fixes.** `security-auditor` and the audit skills report; remediation routes to `core/backend-implementer` (per `core/rules/spring-security.md`) or `core/cleanuper`. The audit recommends; the user acts.
- Never extracts a secret, never prints a personal-data value, never bumps a dependency.
- **PII at rest** — encryption, residency, retention, backups — is the infra suite's `/pii-audit`, not this plugin. This plugin owns data *in motion* through application code.
- Ships **no hooks** by design. QA-artifact staleness surfaces when `core/code-reviewer` runs at `scope=service`, not on every edit.

## Dependencies

Requires `komdosh-dev-spring-core`. Every command starts with core's `read-service-context`; the PII audit calls core's `pii-safety-scan`; `code-reviewer` at `scope=service` (core) reports missing or stale QA artifacts at WARNING level — never BLOCKER, because they are tooling outputs, not production requirements.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` for internal ones).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/security-audit.md
@rules/platform-module.md
