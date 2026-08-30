# komdosh-dev-spring-quality

Audits and QA artifacts on top of `komdosh-dev-spring-core`. One theme: **find out what is actually true about a finished service** — is it secure, is it leaking personal data, is it coupled to a vendor it shouldn't be, and can a human exercise it by hand.

Read-only throughout, except the QA writers, which only ever write under `docs/qa/`.

## Boundary

- **Audits, never fixes.** Remediation routes to core's `backend-implementer` or `cleanuper`. The audit recommends; the user acts.
- Never extracts a secret, never prints a personal-data value, never bumps a dependency.
- **PII at rest** — encryption, residency, retention, backups — is the infra suite's `/pii-audit`. This plugin owns personal data *in motion* through application code.
- Ships **no hooks** by design. QA-artifact staleness surfaces when core's `code-reviewer` runs at `scope=service`, not on every edit.

## Two structural decisions worth knowing

**The PII scan lives in core, not here**, and takes `depth=fast|audit`. `/pii-leakage-check` calls `core/pii-safety-scan` at `depth=audit`. Depth is a parameter, not a plugin boundary — a second copy of the lexicon would drift from the first.

**`/qa` runs one `discover-api-surface` pass for all three writers.** Three separate commands rediscovered the surface three times and could describe three different snapshots of the same API. The writers stay separate because their outputs genuinely differ — a markdown checklist, a Postman JSON schema, and a standalone HTML app share their inputs, not their bodies — and `all` runs them in parallel over disjoint paths.

## Composition

Every command starts with core's `read-service-context`. Core's `code-reviewer` at `scope=service` reports missing or stale QA artifacts at **WARNING, never BLOCKER** — they are tooling outputs, not production requirements.

@rules/security-audit.md
@rules/platform-module.md
