---
description: Audit personal data on the data-in-motion surface — logs, traces, metric tags, MDC, error bodies, response DTOs, event payloads — never printing a value.
---

# /pii-leakage-check

`security-auditor --scope=pii`, which runs core's `pii-safety-scan` at `depth=audit`.

`read-service-context` first. Criteria and severities are `core/rules/pii-handling.md`.

**The report discloses `file:line` and the field name — never a personal-data value.** State that explicitly in the output so a reader can trust it.

Two findings need a cross-check the scan can't make alone: a response exposing **another subject's** PII is a BLOCKER rather than a WARNING (confirm the missing ownership check against `/auth-audit`), and PII in an error body also appears in the error-leakage pass — report it once.

**PII at rest — encryption, residency, retention, backups — is out of scope here**; that is the infra suite's `/pii-audit`.

Write `docs/security/pii-leakage-YYYY-MM-DD.md`.
