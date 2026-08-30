# Release Engineering

Two tracks: **service** (deployed to k8s) and **library** (published to a Maven repository). A repo is one or the other, never both.

## Shared

### Conventional Commits drive the bump

`feat:` → minor · `fix:`/`perf:`/`refactor:` → patch · `docs:`/`test:`/`chore:`/`ci:` → no bump, omitted from the changelog · `feat!:`/`fix!:` or a `BREAKING CHANGE:` footer → **major**. Scopes (`feat(orders):`) group changelog entries.

`detect-release-type` computes the recommendation from commits since the last tag. **A user override is recorded with its rationale in the release PR** — an unexplained override is how a major ships as a patch.

**Silent breaking is forbidden on both tracks.** Any breaking change is advertised by `!` or a `BREAKING CHANGE:` footer in at least one commit.

### CHANGELOG

Keep a Changelog, at the project (or service) root. Header `## [vX.Y.Z] — YYYY-MM-DD`, ISO 8601, no time. Sections in order — Added · Changed · Deprecated · Fixed · Breaking · Removed · Security — empty ones omitted. Each entry keeps its commit scope and PR reference.

Pre-release tags (`-rc.1`, `-beta.2`) are informational and **do not advance the changelog**; only the unsuffixed version does.

### Release PR

Always `release: vX.Y.Z`, opened by `release-coordinator`, reviewed and merged by the user. **Pushing a tag directly bypasses review and is forbidden.**

## Service track

**Breaking** if a migration changes a column or table pre-deploy code cannot read (dropping a NOT NULL column, narrowing a type, renaming without a temporary alias), a public endpoint changes URL/method/shape observably, a consumed event's payload changes, or a config key is renamed or removed without an alias.

New endpoints, new optional fields, and new nullable columns are **not** breaking.

### Rollback classification — per migration in the window

| Class | Examples | Strategy |
|---|---|---|
| Mechanically reversible | add nullable column, create index, deferrable constraint | Inverse DDL in the playbook |
| Reversible with data loss | drop column/table | **Refuse to emit an inverse.** "Forward-fix only" with rationale and a sketch of the corrective migration |
| Type-narrowing / NOT NULL tightening | set NOT NULL after backfill | Forward-fix only — the backfill ran under the old code, so rollback must re-widen |

`produce-rollback-playbook` writes `docs/release/playbooks/<version>.md`. **It also names the ENV vars and feature flags that must move atomically with the rollback** — a reverted deploy with a flag still on is a half-rollback.

### Flags and smoke

Non-trivial changes dark-launch behind a flag; a flag hard-coded `true` in the release is a removal candidate for the next one. Readiness confirms `/actuator/health` returns 200 on the staging-equivalent profile.

## Library track

**Breaking** if a public symbol is removed or renamed without a `@Deprecated(level = HIDDEN)` shim preserving the binary signature for at least one minor · a public signature changes (parameter type or count, return type, generic bound, suspend-ness) · a public property's type, mutability, or visibility changes · a default-value parameter changes such that callers must recompile · a public `@JvmInline value class` changes shape · a public class's supertypes change · an interface's default method is removed.

**Adding a member to a `sealed` hierarchy is breaking too** — every exhaustive `when` in a consumer stops compiling. It gets listed as breaking, not as an addition.

### Internal vs public

Non-public surface is `internal` or lives in a `*.internal.*` package. `verify-release-readiness-library` flags any `public` symbol in an internal package.

A Kotlin-only API should use `kotlinx.binary-compatibility-validator` with committed `api/` baselines — `produce-abi-report` treats those as the source of truth.

### Deprecation

1. `@Deprecated` with `replaceWith` — **mandatory when a successor exists**.
2. The **sunset version stated in the message**: "Use `newApi()`. Removed in v2.0."
3. `level = WARNING` → `ERROR` one minor before removal → `HIDDEN` in the version that removes it, so the binary signature survives.
4. A `### Deprecated` changelog entry carrying the sunset version.
5. `/abi-check` afterwards to confirm the ABI is still compatible.

**`release-coordinator` refuses a major that removes a symbol which has not been at `level = ERROR` for at least one prior release.**

### Publish hygiene

The POM carries `developers` (name + email), `scm`, `licenses` with an SPDX id, `description`, and `url`; sources and javadoc/dokka jars are published; **no `-SNAPSHOT` in the resolved configuration**. Maven Central artifacts are GPG-signed — `check-publish-config` verifies signing is *configured* and never touches the key.

## Anti-patterns

- **Using `--no-verify` to get a release commit through.** A failing readiness check is a cause to fix, not a gate to bypass.
- **Editing an applied changeset to "fix" a release.** Use a corrective changeset (service) or deprecate-and-replace (library).
- **Cherry-picking onto a release branch without bumping.** The branch's last commit is the bump commit; cherry-picks land via PR.
- **Publishing a `-SNAPSHOT` to a release repository.**
- **Mixing tracks in one repo.** Multi-module releases (N libraries plus a service) are out of scope; track is per project.
