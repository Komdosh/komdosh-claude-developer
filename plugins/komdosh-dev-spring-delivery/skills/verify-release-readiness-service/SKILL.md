---
name: verify-release-readiness-service
user-invocable: false
description: "Service-track release readiness composite gate. Runs run-verification, liquibase-changeset-immutability, check-adr-required, scans for `// TODO(release)` markers, confirms no uncommitted changes, checks QA artifact freshness (if qa plugin installed), and probes a smoke endpoint on the staging-equivalent profile if reachable. PASS only when every sub-gate passes. Read-only — never modifies code or commits."
---

# Release Readiness — Service Track

Refuse on a library project (`verify-release-readiness-library` is its counterpart). Read-only: never edits, never deploys, never tags.

**Every sub-gate runs; any FAIL fails the composite.** Never skip one to make the report green.

Order is cheap-first, so a cheap failure surfaces before the user pays for verification.

| # | Sub-gate | Verdict and remediation |
|---|---|---|
| 1 | Clean working tree | FAIL with the file list — commit or stash first |
| 2 | No `TODO(release)` / `FIXME(release)` markers | FAIL with the matches |
| 3 | `run-verification` green | FAIL routed by category: test → `/test-fix`, compile → `backend-implementer`, detekt → `cleanuper` |
| 4 | `liquibase-changeset-immutability` clean | FAIL → revert and add a corrective changeset via `/add-migration` |
| 5 | `check-adr-required` over `last_tag..HEAD` satisfied | FAIL only when REQUIRED and no ADR newer than the tag exists → `/adr-new` |
| 6 | QA artifacts newer than the newest `*Controller.kt` | **SKIP if `spring-quality` isn't installed** — not a FAIL. Artifacts that were never generated are a decision, not staleness. Otherwise FAIL with the stale list → `/qa` |
| 7 | Staging `/actuator/health` returns `UP` | **WARN, never FAIL** — no staging URL configured is not a release defect; the skill assumes no staging access |

Statuses: **PASS** · **FAIL** (fails the composite) · **N/A** (doesn't apply on this branch) · **SKIP** (plugin absent) · **WARN** (best-effort couldn't run).

## Output

The gate table with evidence and remediation per row, plus JSON — `track`, `composite`, `sub_gates[]`, `first_failure` — in the same shape `lifecycle-status` emits, so gate 17 consumes it directly.

On `FAIL` the caller stops and reports. This skill only reports; it advances no state, and the composite is recomputed on every run.
