# /pii-leakage-check [--module=<glob>]

Audit a Kotlin/Spring service for **personal-data (PII) exposure** on its data-in-motion surface — logs, traces, error responses, DTOs, and event payloads. Produces findings classified BLOCKER / WARNING / INFO with file:line and the PII field. Never prints the personal-data value.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if it has not run this session. Refuse if `kind == library` (libraries are audited at the consumer's edge).

- [ ] **Step 2: Invoke `security-auditor` scoped to PII**

Pass `--scope=pii` (and `--module=` to narrow to a package/directory). The agent runs the `scan-pii-exposure` skill, classifies each finding per the PII-exposure category in `rules/security-audit.md`, and writes the findings into the consolidated report (or a PII-only report when run standalone).

- [ ] **Step 3: Surface the output**

Print verbatim:
- The BLOCKER/WARNING/INFO counts and the file:line findings (PII field named, value never printed).
- The single highest-impact remediation.

- [ ] **Step 4: Route follow-ups**

- **Logging/trace leaks** → fix in place (log a surrogate ID; add a redacting `toString()` to the PII value class per `core/rules/pii-handling.md`), or route to `core/cleanuper` for the mechanical change.
- **Error-body leaks** → `core/cleanuper` / `core/security-expert` (also overlaps `/error-leakage-check`).
- **Storage / residency / erasure-at-rest** (encryption, 152-FZ localization, backups) → the infra suite's `/pii-audit` (`data-protection-auditor`) — out of this service-code audit's scope.
- **Missing ownership check exposing another subject's PII** → run `/auth-audit` to confirm the route↔filter coverage.

This audit covers the application's data-in-motion surface only; the infrastructure data lifecycle is `komdosh-dev-infra-core`'s `/pii-audit`.
