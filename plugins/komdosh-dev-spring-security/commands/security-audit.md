# /security-audit [--scope=auth|error-leakage|jwt|pii|all] [--module=<glob>]

Run the full Spring-specific security audit (or a single category if `--scope` is set). Produces `docs/security/audit-YYYY-MM-DD.md` with findings classified BLOCKER / WARNING / INFO + per-finding remediation. The `pii` scope covers personal-data exposure on the data-in-motion surface (also reachable directly via `/pii-leakage-check`).

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if it has not run this session. Refuse if `kind == library` (libraries are audited at consumer edge).

- [ ] **Step 2: Invoke `security-auditor`**

Pass:
- `--scope` if supplied (default: all three sub-audits).
- `--module` to narrow the route/handler enumeration to a specific package or directory.

The agent runs the matching sub-skills (`match-routes-to-filters`, `check-error-leakage`, `audit-jwt-rotation`, `scan-pii-exposure`), classifies findings per `rules/security-audit.md`, and writes the consolidated report.

- [ ] **Step 3: Surface the agent's output**

Print verbatim. Show:
- Summary table (BLOCKER/WARNING/INFO counts per category)
- Posture verdict (CLEAN / ATTENTION-NEEDED / BLOCKED FROM SHIP)
- The path to the full report
- The single highest-impact remediation

- [ ] **Step 4: Suggest follow-ups**

Per finding category:

- **Auth BLOCKERs**: "Run `core/security-expert` to add the missing rule(s)."
- **Error-leakage BLOCKERs**: "Run `core/cleanuper` to mechanically convert handlers to ProblemDetail; for handlers that need redesign, route to `core/security-expert`."
- **JWT BLOCKERs**: "These are configuration changes — apply directly in `boot/SecurityConfig.kt` (or the equivalent) and re-run `/security-audit` to confirm."
- **PII-exposure BLOCKERs**: "Log surrogate IDs and add redacting `toString()` to PII value classes (`core/rules/pii-handling.md`); route mechanical fixes to `core/cleanuper`. For PII at rest (encryption/residency/erasure), run the infra suite's `/pii-audit`."
- **Posture is CLEAN**: "No action needed; recommend re-running before next release."
- **Posture is BLOCKED FROM SHIP**: "Address every BLOCKER before `/release-prep`. The release plugin does not auto-invoke this audit, so a release with known security BLOCKERs is reckless."

If the agent reported `applicable: false` for the JWT sub-audit, surface that as INFO ("no JWT decoder configured — N/A; security audit covers auth + error-leakage only").
