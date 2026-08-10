---
name: write-changelog
user-invocable: false
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git log:*), Bash(git describe:*), Bash(git rev-list:*), Bash(gh pr list:*)
description: Reads git log <last-tag>..HEAD, classifies each commit via Conventional Commits, groups entries into Added / Changed / Deprecated / Fixed / Breaking / Removed / Security, and prepends a Keep-a-Changelog section to CHANGELOG.md. Handles scopes, breaking-change footers, and PR references, and optionally enriches terse commits with rationale via the revealer plugin. Never invents an entry, never rewrites a prior section, never commits. Used by /changelog and by release-coordinator.
---

# Write Changelog

Produce one new section in `CHANGELOG.md` from the commits since the last release tag. **Every line must trace to a real commit on the branch** — a changelog entry that doesn't is worse than a missing one, because it becomes the record.

This is a skill rather than an agent because it is a deterministic transform (git log → grouped markdown) that `release-coordinator` runs mid-pipeline. As an agent it was a nested subagent hop inside an already-agentic flow, paying a context handoff for no isolation benefit.

## Inputs

- **Target version** — `vX.Y.Z`, from `/version-bump`, `release-coordinator`, or the user.
- **CHANGELOG path** — optional; defaults to the project root.

## Steps

- [ ] **Step 1: Locate the last release tag**

```bash
last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || echo "")
[ -n "$last_tag" ] || last_tag=$(git rev-list --max-parents=0 HEAD | head -1)
```

If the repo has never been tagged, the root commit is the base — state that explicitly in the report rather than silently producing a changelog covering all history.

- [ ] **Step 2: Read the commits**

```bash
git log "$last_tag..HEAD" --pretty=format:'%H%x09%s%x09%b%x1e' --no-merges
```

Each record is `<sha>\t<subject>\t<body>`, separated by `\x1e`. Parse:

- the Conventional-Commits prefix (`feat|fix|perf|refactor|docs|test|chore|ci|build|style|revert`);
- an optional scope — `feat(orders): …`;
- an optional `!` breaking marker — `feat!:` / `feat(orders)!:`;
- a `BREAKING CHANGE:` footer in the body.

Skip `docs`, `test`, `chore`, `ci`, `build`, and `style` commits **unless** they carry a `BREAKING CHANGE:` footer.

- [ ] **Step 3: Group by section**

| Conventional-Commits signal | Section |
|---|---|
| `feat:` | Added |
| `feat:` that renames or modifies (subject says "rename", "change", "update behaviour") | Changed |
| `fix:`, `perf:` | Fixed |
| `@Deprecated` in the diff (library track), or `feat: deprecate …` | Deprecated |
| `feat!`, `fix!`, `refactor!`, or a `BREAKING CHANGE:` footer | Breaking |
| `feat: remove …`, `refactor: remove …` (after a deprecation cycle) | Removed |
| A CVE id, or a `security` scope | Security |

Within a section, list entries oldest-first. One bullet each:

```
- <subject with the prefix stripped> (<scope>) (#<PR>) [<short-sha>]
```

```
- bulk-create endpoint (orders) (#123) [a1b2c3d]
- rename `customerEmail` → `email` in `CreateOrderRequest` (orders) (#127) [4e5f6g7]
```

Take the PR number from the commit's `(#NNN)` suffix, or `gh pr list --state merged --search <sha>`. Omit it if unknown — never guess one.

- [ ] **Step 4: Optionally enrich terse commits**

If a subject is terse (`fix: handle edge case`, `refactor: cleanup`) *and* `komdosh-dev-revealer` is installed, call `reveal-knowledge` with the commit subject + body for a related ADR, spec, or note. If a one-line rationale comes back, add it as a sub-bullet:

```
- handle edge case in payment retry (payments) (#129) [8h9i0j1]
  - Rationale: ADR-0042 documented bounded retry; this fixes a missed timeout case.
```

Skip silently when revealer is absent. Never block on it, and never write a rationale the retrieval didn't return.

- [ ] **Step 5: Compose the section**

```markdown
## [vX.Y.Z] — YYYY-MM-DD

### Added
### Changed
### Deprecated
### Fixed
### Breaking
### Removed
### Security
```

Omit empty sections. Date is today, ISO 8601, no time component.

- [ ] **Step 6: Update `CHANGELOG.md`**

If the file exists, insert the new section directly after the header / `## [Unreleased]` block. If `## [Unreleased]` has content, **move** it into the new version and reset `## [Unreleased]` to empty.

If the file doesn't exist, create it:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

<NEW SECTION GOES HERE>
```

- [ ] **Step 7: Report**

```
Changelog updated: CHANGELOG.md
  Version added:    vX.Y.Z
  Sections written: <list>
  Entries:          <total> across <N> sections
  Terse entries enriched: <K of M>   (revealer <installed|absent>)
  Skipped commits (chore/ci/test/build): <count>
  Suggested commit:
    git add CHANGELOG.md
    git commit -m "chore(release): update changelog for vX.Y.Z"
```

Print the suggested commit; **do not run it.** The user or `release-coordinator` commits.

## Forbidden

- Inventing an entry that doesn't trace to a commit.
- Rewriting a prior CHANGELOG section — only the new one is added.
- Including merge commits, or dependency bumps (`chore(deps): bump X`) unless they fix a CVE, which go to Security.
- Bumping the version number — that's `/version-bump`.
