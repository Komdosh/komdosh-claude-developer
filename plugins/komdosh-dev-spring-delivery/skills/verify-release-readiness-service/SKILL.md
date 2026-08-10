---
name: verify-release-readiness-service
user-invocable: false
description: "Service-track release readiness composite gate. Runs run-verification, liquibase-changeset-immutability, check-adr-required, scans for `// TODO(release)` markers, confirms no uncommitted changes, checks QA artifact freshness (if qa plugin installed), and probes a smoke endpoint on the staging-equivalent profile if reachable. PASS only when every sub-gate passes. Read-only — never modifies code or commits."
---

# Verify Release Readiness — Service Track

## When to Use

Run this skill from the `release-coordinator` agent on the **service track**, or directly from the `/release-prep` command after track is confirmed as `service`. Also invoked by the orchestrator's gate 17 when the release plugin is installed and the track is service.

Read-only. The skill never edits files; it reports gate status with remediation.

## Do NOT

- Run on a library-track project. The library equivalent is [`verify-release-readiness-library`](../verify-release-readiness-library/SKILL.md).
- Skip a sub-gate to make the report green. Every sub-gate runs; failure of any one fails the composite.
- Run the actual deploy or push tags. This skill is read-only.

## Steps

- [ ] **Step 1: Confirm track is service**

If `read-service-context` previously emitted `kind: library`, REFUSE. State: "service-track readiness skill invoked on a library project — caller should invoke `verify-release-readiness-library` instead."

- [ ] **Step 2: Sub-gate — clean working tree**

```bash
git diff --quiet && git diff --cached --quiet || echo "DIRTY"
```

- PASS if clean.
- FAIL with: "Uncommitted changes present. Commit or stash before /release-prep. Files: <list>."

- [ ] **Step 3: Sub-gate — no `TODO(release)` markers**

```bash
git grep -nE 'TODO\(release\)|FIXME\(release\)' -- '*.kt' '*.kts' '*.yaml' '*.yml' || true
```

- PASS if zero matches.
- FAIL with the matching files. Remediation: address each marker before release.

- [ ] **Step 4: Sub-gate — full verification**

Invoke the `run-verification` skill (in core).

- PASS if `BUILD SUCCESSFUL` for all three steps.
- FAIL with the failing module + first error category. Remediation:
  - Test failure → `/test-fix`
  - Compile failure → invoke `backend-implementer`
  - Detekt violation → invoke `cleanuper`

- [ ] **Step 5: Sub-gate — Liquibase changesets immutable**

Invoke `liquibase-changeset-immutability` skill (in core).

- PASS if no applied changeset has been edited.
- FAIL with the modified files. Remediation: revert the edit; add a new corrective changeset via `/add-migration`.

- [ ] **Step 6: Sub-gate — ADR present for new architectural surface**

Run `check-adr-required` skill (in core) on the diff `last_tag..HEAD`.

- PASS if NOT REQUIRED, or REQUIRED and a new ADR file exists in `docs/adr/` newer than `last_tag`.
- FAIL if REQUIRED and no ADR. Remediation: `/adr-new` with the architectural decision.

- [ ] **Step 7: Sub-gate — QA artifacts fresh (only if qa plugin installed)**

Detect installed plugins:

```bash
qa_installed=$(find "$HOME/.claude/plugins" "$HOME/.claude/plugins/cache" \
  -maxdepth 4 -type d -name 'komdosh-dev-spring-quality' 2>/dev/null | head -1)
```

If absent: SKIP this gate (not a FAIL).

If present: check that each of `docs/qa/manual-validation-plan.md`, `docs/qa/postman/*.postman_collection.json`, `docs/qa/qa-console.html` (whichever exist) have an mtime >= the newest `*Controller.kt` mtime.

- PASS if all fresh or files do not exist (different decision: never generated).
- FAIL with stale files. Remediation: run `/qa plan`, `/qa postman`, `/qa console` for whichever artifact is stale.

- [ ] **Step 8: Sub-gate — smoke endpoint reachable (best-effort)**

If a `staging` or `dev` profile is configured AND the user has set `RELEASE_PREP_STAGING_BASE_URL` env var:

```bash
curl -sf -m 5 "$RELEASE_PREP_STAGING_BASE_URL/actuator/health" | jq -r '.status' || echo "UNREACHABLE"
```

- PASS if returns `UP`.
- WARN (not FAIL) if unreachable or env not set. The skill does not assume staging access.

- [ ] **Step 9: Compose the gate table**

```
Gate                                  Status    Evidence / Remediation
─────────────────────────────────────────────────────────────────────────
clean working tree                    PASS
no TODO(release) markers              PASS
full verification                     FAIL      :adapters:outbound:test failed (1) — run /test-fix
liquibase immutability                PASS
ADR for new architectural surface     N/A       check-adr-required → NOT REQUIRED
QA artifacts fresh                    SKIP      qa plugin not installed
smoke endpoint reachable              WARN      RELEASE_PREP_STAGING_BASE_URL not set
```

Status semantics:
- **PASS** — sub-gate green.
- **FAIL** — sub-gate red; the composite gate fails.
- **N/A** — sub-gate doesn't apply on this branch (no signals for ADR, no QA changes, etc.).
- **SKIP** — required plugin not installed.
- **WARN** — best-effort sub-gate couldn't run (e.g. no staging URL); not a blocker.

- [ ] **Step 10: Emit the JSON summary**

```json
{
  "track":            "service",
  "composite":        "PASS | FAIL",
  "sub_gates":        [
    { "name": "clean-tree",            "status": "PASS" },
    { "name": "todo-release",          "status": "PASS" },
    { "name": "full-verification",     "status": "FAIL",  "evidence": "...", "remediation": "/test-fix" },
    ...
  ],
  "first_failure":    "full-verification"
}
```

If composite is `FAIL`, the calling agent stops here and reports. If `PASS`, the calling agent proceeds to changelog / version-bump / playbook / PR.

## Output

The markdown table + the JSON summary. Same shape as `lifecycle-status` so the orchestrator's gate 17 can consume it directly.

## Notes

- This skill does not advance state — it only reports. The composite gate is recomputed every time the skill runs.
- For repos without `service.yaml`, the skill falls back to build heuristics (see `release-coordinator` Step 2). If the heuristics are ambiguous, the skill refuses with a clear message.
- The `run-verification` sub-gate is the slowest. The skill runs sub-gates in the cheap-first order so cheaper failures are surfaced before the user pays the verification cost.
