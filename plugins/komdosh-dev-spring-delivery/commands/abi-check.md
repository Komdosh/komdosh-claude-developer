# /abi-check [base-tag]

**Library track only.** Diffs the public API surface against the last released tag (or a user-supplied base) and reports the per-symbol classification: added / deprecated / changed-signature / removed. Drives version-bump decisions on the library track.

Refuses on the service track — services don't have a publish-time ABI surface.

## Steps

- [ ] **Step 1: Confirm track is library**

Run `read-service-context`. If `kind != library`, REFUSE:
```
ABI checks apply to library-track projects only.
Service-track equivalent: HTTP / event contracts — handled by /qa postman and event-consumer-author.
```

- [ ] **Step 2: Determine the base for the diff**

If the user supplied a tag, use it.

If not, default to the most recent published release tag:
```bash
last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-rc*' --exclude '*-alpha*' --exclude '*-beta*' 2>/dev/null)
```

- [ ] **Step 3: Invoke `produce-abi-report` skill**

The skill prefers `kotlinx.binary-compatibility-validator` when configured (`api/<module>.api` baseline files). If the project has the plugin applied:

```bash
./gradlew apiCheck 2>&1 | tail -40
```

If no baseline is committed, the skill falls back to running `apiDump` against both the base tag (in a worktree) and HEAD, then diffs the two `.api` files.

If `kotlinx.binary-compatibility-validator` is NOT configured, the skill recommends adding it (the configuration is small and stabilizes future ABI checks). As a fallback for now, it uses `japicmp` against the published jar and the local jar:

```bash
./gradlew :module:jar
japicmp -o old=<published-jar> new=<local-jar> --html-file abi-report.html --semantic-versioning
```

- [ ] **Step 4: Classify deltas**

| Delta | Class |
|---|---|
| New `public` symbol | added |
| Symbol marked `@Deprecated` (was previously not) | deprecated |
| Public function: parameter type/count/order changed; return type changed; visibility narrowed; suspending status changed | changed-signature (= breaking) |
| Public property: type changed; mutability changed; visibility narrowed | changed-signature (= breaking) |
| Public symbol removed | removed (= breaking) |
| New default parameter on existing public function | additive (added with caveat — note ABI is preserved, source compatibility is preserved) |
| Sealed hierarchy: new sealed member | breaking (downstream `when` exhaustiveness changes) |
| Internal-only changes | invisible (skipped from report) |

- [ ] **Step 5: Write the report**

Output: `docs/release/abi-vX.Y.Z.md` (or `abi-HEAD.md` if no version is set yet).

```markdown
# ABI Report — base vX.Y.Z → HEAD

Generated: YYYY-MM-DD

## Summary

- Added:    N
- Deprecated: K
- Changed-signature: M  (= breaking)
- Removed: P  (= breaking)

Recommended bump: <patch | minor | major>

## Added (N)

- `com.example.lib.NewClass`
- `com.example.lib.MyClass.newFunction(x: Int): String`

## Deprecated (K)

- `com.example.lib.MyClass.oldFunction(x: Int): String` — sunset v1.6.0

## Changed-signature — BREAKING (M)

- `com.example.lib.MyClass.someFunction(x: Int): String`
  - was: `(x: Int) -> String`
  - now: `(x: Int, y: String) -> String`
  - Migration: callers must pass `y`. Default value possible? <yes/no>.

## Removed — BREAKING (P)

- `com.example.lib.MyClass.removedFunction` — was deprecated since v1.2.0
```

- [ ] **Step 6: Report**

```
ABI report: docs/release/abi-vX.Y.Z.md
  added:               <N>
  deprecated:          <K>
  changed-signature:   <M>  (BREAKING)
  removed:             <P>  (BREAKING)
  Recommended bump:    <patch | minor | major>

If breaking deltas appear and the proposed version bump is not major, /version-bump will refuse to apply a lesser bump.
```

If `kotlinx.binary-compatibility-validator` is not configured, also:

```
ABI baseline: NOT CONFIGURED — recommend adding the kotlinx.binary-compatibility-validator plugin and committing the api/ baseline. /publish-prep will warn until this is fixed.
```
