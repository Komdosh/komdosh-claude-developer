---
name: produce-rollback-playbook
description: "Service track. For each Liquibase changeset added in the release window, classify rollback as mechanically reversible / forward-fix only / type-narrowing, emit inverse SQL where possible, and surface ENV vars and feature flags that must move atomically with rollback. Writes docs/release/playbooks/<version>.md. Read-only on source; writes one doc."
---

# Produce Rollback Playbook

## When to Use

Use this skill on the **service track** during release prep. The output is a per-release playbook the on-call engineer reads if a rollback is required.

Refuses on the library track — libraries don't roll back.

## Do NOT

- Fabricate a reverse SQL for a destructive migration (`DROP COLUMN`, `DROP TABLE`, type-narrowing, NOT NULL tightening). Those are forward-fix only — the skill states this explicitly with rationale.
- Assume the user has a backup. Rollback strategy is "what if no backup is available."
- Run any migration. Read-only.

## Steps

- [ ] **Step 1: Confirm track is service**

If `kind == library`, REFUSE.

- [ ] **Step 2: Determine the release window**

Default: `$(git describe --tags --abbrev=0)..HEAD`. The caller (`/rollback-playbook` or `release-coordinator`) may pass an explicit version range.

- [ ] **Step 3: List newly-added migrations**

```bash
git log "$base..HEAD" --diff-filter=A --name-only \
  -- '*/db/changelog/V*.sql' \
  | grep -E '/db/changelog/V.*\.sql$' \
  | sort -u
```

For each file, read its content.

- [ ] **Step 4: Classify each changeset**

Parse the SQL statements (handle Liquibase formatted-SQL comments). For each statement, classify:

| Statement pattern | Class | Inverse |
|---|---|---|
| `CREATE TABLE foo (...)` | mechanically reversible | `DROP TABLE IF EXISTS foo;` |
| `ALTER TABLE foo ADD COLUMN bar TYPE` (nullable, no DEFAULT requiring data) | mechanically reversible | `ALTER TABLE foo DROP COLUMN IF EXISTS bar;` |
| `ALTER TABLE foo ADD COLUMN bar TYPE NOT NULL` (no backfill) | mechanically reversible (the column is empty by definition) | `ALTER TABLE foo DROP COLUMN IF EXISTS bar;` |
| `ALTER TABLE foo ADD COLUMN bar TYPE NOT NULL DEFAULT ...` | reversible-with-data-loss (column drops cascade-lose data) | "Forward-fix only — restoring the column requires re-creating it AND restoring backfilled data from a backup." |
| `CREATE INDEX idx_foo ON foo (...)` | mechanically reversible | `DROP INDEX IF EXISTS idx_foo;` |
| `CREATE UNIQUE INDEX idx_foo ON foo (...)` | mechanically reversible (idempotent) | `DROP INDEX IF EXISTS idx_foo;` |
| `ALTER TABLE foo ADD CONSTRAINT c_foo ...` | mechanically reversible | `ALTER TABLE foo DROP CONSTRAINT IF EXISTS c_foo;` |
| `ALTER TABLE foo ALTER COLUMN bar SET NOT NULL` (after a backfill) | type-narrowing | "Forward-fix only — re-widening NULL requires a corrective migration applied on top of the rollback." |
| `ALTER TABLE foo ALTER COLUMN bar TYPE smaller_type` | type-narrowing | "Forward-fix only." |
| `ALTER TABLE foo DROP COLUMN bar` | reversible-with-data-loss | "Forward-fix only." |
| `DROP TABLE foo` | reversible-with-data-loss | "Forward-fix only." |
| `INSERT INTO ...`, `UPDATE ...`, `DELETE ...` | data migration | "Reversibility is data-shape-dependent — surface to operator." |

If the changeset already includes an explicit `--rollback ...` clause (Liquibase formatted SQL convention), prefer that as the inverse — it's the developer's intent.

- [ ] **Step 5: Detect feature flags / ENV vars introduced in the window**

Look for:

- New `@ConditionalOnProperty(name = "...", havingValue = "...")` annotations in `last_tag..HEAD`.
- New `@Value("\${...}")` or `${...}` references in `application.yaml` / `application-*.yaml`.
- New `feature.flags.*` keys in any `application*.yaml`.

For each, list as "must flip with rollback" or "must clear with rollback" depending on whether the new release set the flag to `true`.

- [ ] **Step 6: Detect application.yaml additions**

```bash
git diff "$base..HEAD" -- '*.yaml' '*.yml' | grep -E '^\+[^+]' | grep -vE '^\+\+\+' | head -50
```

Surface added top-level keys as ENV-variable changes the operator should be aware of.

- [ ] **Step 7: Compose the playbook**

Write to `docs/release/playbooks/<version>.md`. Format per the `/rollback-playbook` command spec — one section per migration plus the feature-flags / ENV-var sections plus a smoke checklist.

- [ ] **Step 8: Output**

Print the playbook path + a counts summary:

```
Playbook: docs/release/playbooks/vX.Y.Z.md
  Migrations:
    Mechanically reversible:        N
    Reversible-with-data-loss:      K
    Type-narrowing / NOT-NULL:      M
    Data migrations (eyes-on):      P
  Feature flags affected:           <count>
  ENV vars added:                   <count>
  Suggested commit:
    git add docs/release/playbooks/vX.Y.Z.md
    git commit -m "docs(release): rollback playbook for vX.Y.Z"
```

If any forward-fix-only migrations are present, the skill PROMINENTLY flags them in the report so the calling agent surfaces them before the release proceeds.

## Output

The playbook file path + the counts summary + any prominent warnings. The release-coordinator parses the counts to decide whether to require explicit user acknowledgement before opening the release PR.

## Notes

- The skill does not consider data volume. A `DROP COLUMN` on a column with no data is still classified as forward-fix only — the conservative classification protects against rollback-time surprises.
- For composite changesets that touch multiple tables, classify each statement independently and report the strictest classification across the set.
- For PostgreSQL-specific syntax (`ALTER TABLE ... ALTER COLUMN ... SET DATA TYPE`), the skill recognises the canonical form. For non-Postgres databases, the skill warns that some patterns may not classify correctly.
