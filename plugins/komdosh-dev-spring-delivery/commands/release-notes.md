# /release-notes [version]

Generate human-readable release notes (different audience from `/changelog` — release notes are customer- or consumer-facing; the changelog is a complete dev-facing record).

## Steps

- [ ] **Step 1: Determine the target version**

If supplied, use it. Otherwise read from `CHANGELOG.md` (the most recent non-Unreleased section).

- [ ] **Step 2: Invoke `release-coordinator`** with the request to compose release notes only (skip the readiness gates and PR steps).

The agent reads:
- The CHANGELOG section for the version.
- The commit log scoped to that version (for cross-checking, not duplication).

- [ ] **Step 3: Compose**

Format:

```markdown
# vX.Y.Z — YYYY-MM-DD

## Highlights

- One sentence per major user-visible change. Skip refactors, docs, chores.

## Service track only — Deployment notes

- Migrations: <count>; rollback strategy: <forward-fix-only? mechanically reversible?>.
- Feature flags: <list>.
- Operator action required: <none | description>.

## Library track only — Migration guidance for consumers

- Breaking changes (with code examples for migrating).
- Deprecations (with replacements).
- Recommended upgrade path: <patch consumers can upgrade in place | minor needs review | major needs ADR>.

## Full details

See [CHANGELOG.md](CHANGELOG.md#vX.Y.Z) for the complete record.
```

For service track: skip the "Migration guidance for consumers" section entirely.
For library track: skip the "Deployment notes" section entirely.

Empty sections (e.g., no breaking changes for this release) are omitted, not left empty.

- [ ] **Step 4: Write to `docs/release/notes-vX.Y.Z.md`**

If the file exists, ask before overwriting.

- [ ] **Step 5: Report**

```
Release notes written: docs/release/notes-vX.Y.Z.md
  Highlights:        <N>
  Track-specific:    <count>
  Suggested commit:
    git add docs/release/notes-vX.Y.Z.md
    git commit -m "docs(release): add release notes for vX.Y.Z"
```

If the user is preparing to publish to GitHub Releases, suggest:
```
After tag push:
  gh release create vX.Y.Z --notes-file docs/release/notes-vX.Y.Z.md
```
