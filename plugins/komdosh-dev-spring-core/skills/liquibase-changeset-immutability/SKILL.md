---
name: liquibase-changeset-immutability
allowed-tools: Grep, Glob, Read, Bash(git log:*), Bash(git diff:*), Bash(git show:*)
description: Verify that no previously-applied Liquibase changeset has been edited. A modified changeset fails the next deploy with a checksum mismatch — this skill catches it locally before push. Run before commit when V*.sql files are touched, and as part of /verify-service. Reads git history to determine which changesets are "applied" (committed to main).
---

# Liquibase Changeset Immutability

## When to Use

- Before committing any change that touches files under `*/src/main/resources/db/changelog/V*.sql` or `**/db.changelog-master.yaml`.
- As a CI guard inside `/verify-service` for any service using Liquibase.
- When a deploy mysteriously fails on `Validation Failed: 1 changesets check sum`.

This skill enforces the immutability rule from [`rules/persistence.md`](../../rules/persistence.md):

> **Never modify an applied changeset.** Liquibase tracks each changeset by checksum; a mismatch on the next deploy fails the boot.

## Output

For each changeset that was modified after first being committed:

```
[LBM-1] BLOCKER <file>:V<N>__<slug>.sql
  First committed: <SHA> on <date> ("<commit-msg>")
  Last modified:   <SHA> on <date> ("<commit-msg>")
  Diff lines:      +<added> -<removed>
  Fix: revert this file to <first-SHA>:<file>, then add a NEW changeset V<N+1>__... with the new behaviour
```

Plus the summary line:

```
Liquibase immutability: <CLEAN | N modified changesets>
```

## Steps

- [ ] **Step 1: Locate every changeset file in the repo**

```bash
find . -path '*/db/changelog/V*.sql' \
  -not -path '*/build/*' -not -path '*/.gradle/*' \
  | sort -V
```

- [ ] **Step 2: Decide which changesets are considered "applied"**

A changeset is "applied" when it has been committed to a long-lived branch (typically `main`). Find each file's first commit:

```bash
for f in $(<list from Step 1>); do
  first=$(git log --diff-filter=A --follow --format='%H %ad %s' --date=short -- "$f" | tail -1)
  printf '%s\t%s\n' "$f" "$first"
done
```

If a file has never been committed (untracked or only in the working tree), it is NOT applied yet — skip it.

- [ ] **Step 3: For each applied changeset, look for later modifications**

```bash
for f in <applied-files>; do
  # commits that modified the file AFTER the first add
  modifications=$(git log --diff-filter=M --follow --format='%H %ad %s' --date=short -- "$f")
  [ -n "$modifications" ] && {
    echo "=== $f ==="
    echo "first add: <recorded in step 2>"
    echo "later modifications:"
    echo "$modifications"
  }
done
```

A modification is anything but pure whitespace. Use `git show <SHA> -- "$f"` and `--ignore-all-space` to confirm:

```bash
git diff --ignore-all-space <first-SHA>..HEAD -- "$f" | head -20
```

If the diff is empty under `--ignore-all-space`, the file is effectively unchanged — treat as `WARNING (whitespace-only)` rather than BLOCKER.

- [ ] **Step 4: Special-case rollback edits**

A `--rollback` line edit on an already-applied changeset does NOT change the checksum (Liquibase computes the checksum over the changeset body, not the rollback section). If the only change in the diff is inside a `--rollback` line, downgrade severity to `INFO`:

```
[LBM-2] INFO <file>:V<N>__<slug>.sql
  Modified rollback section only — does not affect Liquibase checksum.
  Acceptable. Note that historic deploys still ran the old rollback if invoked.
```

- [ ] **Step 5: Special-case master changelog**

`db.changelog-master.yaml` is editable — adding new `include:` entries is the normal flow. Do NOT flag it. But removing or reordering existing entries IS a problem (Liquibase may try to re-apply or skip changesets). Flag any deletion of an existing `include:` line:

```bash
git diff origin/main..HEAD -- '**/db.changelog-master.yaml' \
  | grep -E '^-\s*-?\s*include:' \
  | grep -v '^---'
```

If non-empty:

```
[LBM-3] BLOCKER db.changelog-master.yaml
  Removed include of <file> — Liquibase will treat that changeset as never-run.
  Fix: keep the include line; if you really need to drop a changeset, write a new changeset
       that does the inverse (e.g., DROP COLUMN), and leave the original include in place.
```

- [ ] **Step 6: Report**

State the findings using the formats above, then the summary.

If the calling agent wants to proceed despite a flagged change (e.g., the changeset has not yet been deployed to any environment and the team has agreed to amend), the agent must explicitly override — this skill does not auto-clear.

## Fix Patterns

When a real (non-whitespace, non-rollback) modification is detected on an applied changeset, the standard fix is:

1. `git checkout <first-SHA> -- <file>` — restore the original.
2. Find the next free `V<N>` number from `ls db/changelog/V*.sql | sort -V | tail -1`.
3. Write a new `V<N+1>__<verb>-<thing>.sql` that performs the intended additional change (with its own `--changeset`, `--comment`, `--rollback`).
4. Add the new file to `db.changelog-master.yaml`.

Never `--clearCheckSums` in shared environments. That is an emergency-only escape hatch and erases audit history.

## Notes

- This skill does NOT call Liquibase itself — it only inspects git history. The authoritative check is `./gradlew :boot:liquibaseValidate` (or equivalent), which connects to the database and compares stored checksums against current files.
- For services on a release branch other than `main`, replace `origin/main` in the diff command with the appropriate base.
