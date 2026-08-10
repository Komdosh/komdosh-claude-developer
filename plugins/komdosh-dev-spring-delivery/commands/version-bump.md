# /version-bump [target] [--track=service|library] [--dry-run]

Decide the next version number from commit history. On the **service track** the decision is purely Conventional-Commits-based (advisory semver). On the **library track** the decision is **ABI-load-bearing**: any breaking ABI delta forces a major bump regardless of commit prefixes.

`--dry-run` reports the decision without mutating files.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if not already run this session. Determine the track per the precedence rules in [`CLAUDE.md`](../CLAUDE.md#track-auto-detection).

- [ ] **Step 2: Run `detect-release-type` skill**

Output:
```
last_tag    = vX.Y.Z
commits     = N (since last tag)
prefixes    = <count by prefix>
breaking    = <count of feat!|fix!|BREAKING CHANGE: footers>
proposed    = patch | minor | major
rationale   = <one line>
```

- [ ] **Step 3: For library track — run `produce-abi-report` skill**

If the project is library-track, ALWAYS run the ABI report. If it returns any `breaking` deltas, OVERRIDE the proposed bump to `major` and state the override:

```
Proposed bump (commits):  minor
ABI report:               1 breaking, 3 deprecated, 5 added
Final bump:               MAJOR (override — breaking ABI takes precedence over commit signal)
```

If the ABI report shows ONLY additive changes and the commit signal says `patch`, surface this as a softer hint — the user may want to bump to `minor` because new public API was added even if commits don't say `feat:`.

- [ ] **Step 4: Surface the user-supplied target if any**

If the user provided a version (`/version-bump v1.5.0`), compare it to the proposed bump:

- Match: proceed.
- User's target is HIGHER than proposed: proceed (user can always be more conservative or more bold).
- User's target is LOWER than proposed: REFUSE. Print why (e.g. "you proposed v1.4.1 but commits include `feat!:` which forces major") and ask for confirmation to override anyway.

- [ ] **Step 5: For `--dry-run` — STOP**

Print the decision and exit. No file changes.

- [ ] **Step 6: Apply the bump**

Locate the version source:

```bash
# In order of preference:
#   1. version line in build.gradle.kts (root): "version = \"X.Y.Z\""
#   2. project alias in gradle/libs.versions.toml under [versions]
#   3. allprojects { version = "..." } in build.gradle.kts
#   4. version.properties at repo root
```

Edit exactly one occurrence. State the diff. Do NOT touch other configuration.

- [ ] **Step 7: Report**

```
Version bump: vX.Y.Z → vA.B.C  (<bump-type>)
  Source:    <file>
  Rationale: <commits | abi-override | user-override>
  Diff:
    -version = "X.Y.Z"
    +version = "A.B.C"

Suggested commit:
  git add <source-file>
  git commit -m "chore(release): bump version to vA.B.C"
```

Do NOT commit. The user (or `release-coordinator`) commits.

- [ ] **Step 8: If track is library, recommend re-running `/abi-check`**

The bump itself does not change the ABI, but if the user is doing `/version-bump` outside of `/release-prep`, remind them to run `/abi-check` to capture the report before publishing.
