# /changelog [version]

Generate or update a `CHANGELOG.md` entry for the next release. Reads commits since the last release tag, classifies them via Conventional Commits, and writes a Keep-a-Changelog-formatted section. Identical UX on service and library tracks.

## Steps

- [ ] **Step 1: Determine the target version**

If the user supplied one, use it.

If not, look for a version in `gradle/libs.versions.toml` (alias `project` or `app`) or `build.gradle.kts` (`version =`). Use that as the default.

If still ambiguous: ask the user.

- [ ] **Step 2: Run the `write-changelog` skill**

Pass the target version. The skill:

1. Locates the last release tag (falling back to the root commit, and saying so).
2. Reads `git log <last-tag>..HEAD --no-merges`.
3. Groups commits by Conventional-Commits prefix into Added / Changed / Deprecated / Fixed / Breaking / Removed / Security.
4. Optionally enriches terse commits via `reveal-knowledge` when `komdosh-dev-revealer` is installed.
5. Updates `CHANGELOG.md`, creating it with the Keep-a-Changelog header if absent.

Every entry traces to a real commit — the skill never invents one, and never rewrites a prior section.

- [ ] **Step 3: Print the report**

Show the new section that was added, plus stats (entries per section, terse commits enriched, commits skipped).

- [ ] **Step 4: Suggest the commit (do not run it)**

```bash
git add CHANGELOG.md
git commit -m "chore(release): update changelog for vX.Y.Z"
```

If the changelog flagged any breaking changes that the user did not previously call out (no `feat!:` or `BREAKING CHANGE:` footer in any commit), ALERT them — they may need to bump the version's major component via `/version-bump` and reconcile.
