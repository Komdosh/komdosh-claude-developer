---
name: verify-release-readiness-library
user-invocable: false
description: "Library-track release readiness composite gate. Runs run-verification, scans for internal-API leakage in public packages, runs produce-abi-report and check-publish-config, confirms KDoc on public symbols, deprecation hygiene (replacement + sunset), no -SNAPSHOT deps, license headers present. PASS only when every sub-gate passes. Read-only."
---

# Verify Release Readiness — Library Track

## When to Use

Run this skill from the `release-coordinator` agent on the **library track**, or directly from `/release-prep` after track is confirmed as `library`. Also invoked by the orchestrator's gate 17 when the release plugin is installed and the track is library.

Read-only. The skill never edits files; it reports gate status with remediation.

## Do NOT

- Run on a service-track project. Use [`verify-release-readiness-service`](../verify-release-readiness-service/SKILL.md) instead.
- Skip the ABI sub-gate even on patch releases. ABI matters for every release.
- Treat `kotlinx.binary-compatibility-validator` as optional — it is the strongest signal. If absent, downgrade the ABI confidence from PASS to WARN and recommend adding it.

## Steps

- [ ] **Step 1: Confirm track is library**

If `read-service-context` previously emitted `kind: service`, REFUSE.

- [ ] **Step 2: Sub-gate — clean working tree**

Same as service track Step 2.

- [ ] **Step 3: Sub-gate — full verification**

Invoke `run-verification` skill (in core). Same semantics as service track.

- [ ] **Step 4: Sub-gate — no internal-API leakage in public packages**

Public-by-default Kotlin: every top-level declaration without `internal`/`private`/`protected` is `public`. Find leaks where the developer probably meant `internal`:

```bash
# Find files in non-`.internal.` packages that contain symbols the project intends to keep private.
# Heuristic: any file whose path contains '/internal/' but whose declarations are NOT marked `internal`.
grep -lrn -E '^(class|object|interface|fun|val|var) ' \
  --include='*.kt' \
  src/main/kotlin/**/internal/ 2>/dev/null \
  | xargs -I{} grep -lnE '^(public |^)(class|object|interface|fun|val|var) ' {} 2>/dev/null
```

Also flag `class`/`object`/`fun`/`val`/`var` declarations in public packages where the developer left a `// internal` comment but forgot the modifier:

```bash
grep -nE '// internal' --include='*.kt' -r src/main/kotlin || true
```

- PASS if zero matches.
- FAIL with the file:line list. Remediation: add `internal` modifier or move to a `*.internal.*` package.

- [ ] **Step 5: Sub-gate — ABI report reviewed**

Invoke `produce-abi-report` skill (this plugin). The report classifies every delta vs the last release.

- PASS if the report is fresh (mtime >= HEAD commit time) AND the user has acknowledged any breaking deltas (acknowledgement = the report file exists in `docs/release/abi-vX.Y.Z.md`).
- FAIL if the report shows breaking deltas AND the proposed version bump is not major. Remediation: bump version to next major OR remove the breaking change.
- WARN if `kotlinx.binary-compatibility-validator` is not configured (the report falls back to japicmp). Recommend adding the plugin.

- [ ] **Step 6: Sub-gate — deprecation hygiene**

For every `@Deprecated(...)` annotation introduced or modified in `last_tag..HEAD`:

- Must have `message` containing a sunset version (`v1.6.0`).
- Must have `replaceWith` IF the project has a documented successor symbol (this is judgement-call; the skill flags only the absence as a WARN, not a FAIL).
- Level must not regress (e.g., from ERROR back to WARNING).

- PASS if all checks clean.
- FAIL with the offending annotations. Remediation: re-run `/deprecate-api <symbol>`.

- [ ] **Step 7: Sub-gate — KDoc on public symbols**

For every newly-added public symbol in `last_tag..HEAD` (computed via the ABI report's `added` section), confirm a KDoc block immediately precedes the declaration.

```bash
# For each added symbol, find its line and check the line above is part of a /** ... */ block
```

- PASS if every added public symbol has KDoc.
- WARN if some are missing (not FAIL — KDoc is recommended but not strictly blocking for releases). Remediation: invoke `backend-implementer` to add KDoc.

- [ ] **Step 8: Sub-gate — no `-SNAPSHOT` deps**

```bash
./gradlew dependencies --configuration runtimeClasspath 2>&1 | grep -F '-SNAPSHOT' | head -20
```

- PASS if zero matches.
- FAIL with the offending deps. Remediation: bump to release versions via `/upgrade <lib>` (extras plugin) or pin in `libs.versions.toml`.

- [ ] **Step 9: Sub-gate — license headers**

If the project's convention is to require a license header on every Kotlin source (check for an existing header on `src/main/kotlin/**/Application*.kt` or any sample), confirm the header is present on every file added in `last_tag..HEAD`.

- PASS if all present or convention not detected.
- WARN if some are missing. Remediation: copy the header from an existing file.

- [ ] **Step 10: Sub-gate — publish config valid**

Invoke `check-publish-config` skill (this plugin). Forward its PASS / FAIL / WARN per check directly.

- [ ] **Step 11: Compose the gate table**

```
Gate                                  Status    Evidence / Remediation
─────────────────────────────────────────────────────────────────────────
clean working tree                    PASS
full verification                     PASS
no internal-API leakage               PASS
ABI report reviewed                   PASS      added 5 · deprecated 2 · changed 0 · removed 0  → minor bump OK
deprecation hygiene                   PASS
KDoc on added public symbols          WARN      2 of 5 added symbols missing KDoc
no -SNAPSHOT deps                     PASS
license headers                       N/A       no project convention detected
publish config valid                  PASS
```

- [ ] **Step 12: Emit the JSON summary**

```json
{
  "track":            "library",
  "composite":        "PASS | FAIL",
  "sub_gates":        [...],
  "abi_summary":      { "added": 5, "deprecated": 2, "changed": 0, "removed": 0, "recommended_bump": "minor" },
  "first_failure":    null
}
```

## Output

Markdown table + JSON summary. The orchestrator's gate 17 consumes the JSON directly.

## Notes

- The library track does NOT have a smoke-endpoint sub-gate (libraries have no runtime).
- The library track does NOT have a Liquibase sub-gate (libraries have no schema).
- The library track has more sub-gates than the service track; this is intentional — library mistakes are immutable once published.
- For multi-module library repos, run the skill once per published module if the project's publish config emits multiple artifacts. The skill auto-detects multi-publication setups via `./gradlew publishing`.
