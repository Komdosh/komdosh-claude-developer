---
name: produce-abi-report
description: "Library track. Diffs the public Kotlin/Java API surface against the last released tag. Prefers kotlinx.binary-compatibility-validator (api/<module>.api baselines); falls back to japicmp against the published jar. Per-symbol classification: added / deprecated / changed-signature / removed. Drives /version-bump on the library track. Read-only on source; writes one report doc."
---

# Produce ABI Report

## When to Use

Use this skill on the **library track** before any version bump and as a sub-gate of `verify-release-readiness-library`. The report is the source of truth for whether a bump must be major.

Refuses on the service track.

## Do NOT

- Run `apiDump` and OVERWRITE the committed `api/<module>.api` baseline. The baseline IS the prior release's signature; overwriting it destroys the diff.
- Treat additive-only deltas as breaking. New symbols, new optional parameters with defaults, and new sealed members in non-`sealed` open hierarchies are additive. Note: NEW members of an existing `sealed` hierarchy ARE breaking (downstream `when` exhaustiveness).
- Decompile dependency JARs to produce this report. The skill works against the project's own outputs only.

## Steps

- [ ] **Step 1: Confirm track is library**

If `kind != library`, REFUSE.

- [ ] **Step 2: Determine the base**

Default: most recent non-pre-release release tag.

```bash
last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-rc*' --exclude '*-alpha*' --exclude '*-beta*' 2>/dev/null)
```

Caller may override.

- [ ] **Step 3: Choose the diff backend**

Probe for `kotlinx.binary-compatibility-validator`:

```bash
grep -lE 'org\.jetbrains\.kotlinx\.binary-compatibility-validator|kotlinx\.binary-compatibility-validator' \
  build.gradle.kts settings.gradle.kts 2>/dev/null
```

If present AND `api/` baseline files exist:
- **Backend A**: read `api/<module>.api` from `last_tag` (via `git show`) and from HEAD. Diff line-by-line.

If absent OR baseline files do not exist:
- **Backend B (fallback)**: japicmp.
  ```bash
  ./gradlew :module:jar 2>&1 | tail -20
  # Resolve the published jar at last_tag — if it was published to Maven Local or a known repo:
  published_jar=$(find ~/.m2/repository -name "<artifact>-<last_tag-without-v>.jar" 2>/dev/null | head -1 || true)
  # If not found locally, ask the user to point at the published jar or use Backend C.
  ```

If neither backend is workable:
- **Backend C (manual)**: emit a message recommending the user add `kotlinx.binary-compatibility-validator` and commit the baseline. Skip the report; surface the gap to the caller.

- [ ] **Step 4: Run the diff (Backend A)**

For each `api/<module>.api` file:

```bash
git show "$last_tag:api/<module>.api" > /tmp/abi-base.api
diff /tmp/abi-base.api api/<module>.api
```

Parse the diff. Each `<` line is a symbol that existed at base but not at HEAD. Each `>` line is a symbol that exists at HEAD but not at base. Normalise the diff into structured deltas:

| Diff signal | Delta class |
|---|---|
| `>` line declares a new public symbol | added |
| `<` line declares a symbol that does not appear in any `>` line | removed (= breaking) |
| `<` and `>` lines both reference the same symbol but with different signatures | changed-signature (= breaking) |
| `>` line adds `@Deprecated` to a symbol that existed at base | deprecated |
| `<` and `>` describe a `sealed` hierarchy where new members appear | breaking (sealed-hierarchy-grew) |

- [ ] **Step 5: Run the diff (Backend B — japicmp fallback)**

```bash
japicmp -o old="$published_jar" new="<local-jar>" --json-file /tmp/abi.json --semantic-versioning
```

Parse the JSON output. japicmp's classification maps to ours:

| japicmp `compatibility` | Delta class |
|---|---|
| `BACKWARDS_COMPATIBLE` (added) | added |
| `BACKWARDS_COMPATIBLE_NEW_DEFAULT` etc. | added (with note) |
| `NOT_BACKWARDS_COMPATIBLE` (signature change, removal) | changed-signature OR removed |

Cross-check with the source: if the symbol has `@Deprecated`, override the class to `deprecated`.

- [ ] **Step 6: Compose the report**

Write to `docs/release/abi-vX.Y.Z.md` (where `vX.Y.Z` is the proposed version, or `HEAD` if not yet decided). Format per the `/abi-check` command spec.

- [ ] **Step 7: Compute the recommended bump**

| Deltas present | Recommended bump |
|---|---|
| Any `removed` or `changed-signature` or `breaking` | major |
| Any `added` (and no breaking) | minor |
| Only `deprecated` (and no added/breaking) | minor (deprecation is a public API change) |
| No deltas | patch |

State the recommended bump in the report and in the JSON output. The `release-coordinator` reads this and overrides the commit-derived bump if necessary.

- [ ] **Step 8: Output**

```json
{
  "track":            "library",
  "base":             "vX.Y.Z",
  "head":             "abc1234",
  "backend":          "kotlinx-bcv | japicmp | manual",
  "deltas": {
    "added":              N,
    "deprecated":         K,
    "changed_signature":  M,
    "removed":            P
  },
  "recommended_bump": "patch | minor | major",
  "report_path":      "docs/release/abi-vX.Y.Z.md"
}
```

Plus a markdown summary the caller surfaces.

## Output

The report file path + the counts JSON. The composite library readiness skill consumes this; `/version-bump` consumes this; the release-coordinator consumes this.

## Notes

- For repos with a `build-logic/` convention plugin that applies `binary-compatibility-validator` centrally, the skill detects via the included build's transitive plugin set.
- The skill does NOT update the baseline (`apiDump`). Updating the baseline is a deliberate developer action — the skill leaves that to the caller (or to CI on tag push).
- For Kotlin Multiplatform projects, the skill diffs each target's `.api` file separately. This is rare for Spring services but documented for completeness.
