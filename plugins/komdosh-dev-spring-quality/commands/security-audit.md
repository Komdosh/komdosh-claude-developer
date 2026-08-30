---
description: Full Spring security audit — route↔filter coverage, RFC 9457 error leakage, JWT/JWK rotation, and PII in motion — into docs/security/, classified BLOCKER/WARNING/INFO.
argument-hint: "[--scope=auth|error-leakage|jwt|pii|all] [--module=<glob>]"
---

# /security-audit

1. `read-service-context`. **Refuse if `kind == library`** — libraries are audited at the consumer's edge.
2. Invoke `security-auditor` with any `--scope` and `--module`. It runs the matching skills, classifies against `rules/security-audit.md`, and writes `docs/security/audit-YYYY-MM-DD.md`.
3. Surface the summary table with **totals scanned per category**, the posture, the report path, and the single highest-impact remediation.
4. Route the follow-ups:
   - **Auth** → `core/backend-implementer` for the missing rules (`core/rules/spring-security.md`).
   - **Error leakage** → `core/cleanuper` for mechanical `ProblemDetail` conversion; `core/backend-implementer` where the handler needs redesign.
   - **JWT** → configuration changes applied directly, then re-run this command.
   - **PII in motion** → surrogate IDs and redacting `toString()` (`core/rules/pii-handling.md`). **PII at rest is the infra suite's `/pii-audit`.**
   - **No JWT decoder** → surface as INFO "N/A", not as a gap.

`BLOCKED FROM SHIP` means every BLOCKER is addressed before `/release-prep`. **Nothing auto-invokes this audit**, so a release with known security BLOCKERs ships on someone's decision — make sure that is explicit.
