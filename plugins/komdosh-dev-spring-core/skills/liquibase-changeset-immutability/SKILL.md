---
name: liquibase-changeset-immutability
allowed-tools: Grep, Glob, Read, Bash(git log:*), Bash(git diff:*), Bash(git show:*)
description: Verify that no previously-applied Liquibase changeset has been edited. A modified changeset fails the next deploy with a checksum mismatch — this skill catches it locally before push. Run before commit when V*.sql files are touched, and as part of /verify-service. Reads git history to determine which changesets are "applied" (committed to main).
---

# Liquibase Changeset Immutability

Enforces the immutability rule in `rules/persistence.md`: **a modified applied changeset fails the next deploy at boot with a checksum mismatch.** Run before committing any `db/changelog/` change, and when a deploy fails on `Validation Failed: 1 changesets check sum`.

This inspects **git history only** — it never calls Liquibase. `./gradlew :boot:liquibaseValidate` against the real database remains authoritative.

## Method

1. Find every changeset: `find . -path '*/db/changelog/V*.sql' -not -path '*/build/*' | sort -V`.
2. A changeset counts as **applied** once it is committed to the long-lived branch. Get its first commit with `git log --diff-filter=A --follow -- "$f" | tail -1`. Never-committed files are not applied — skip them.
3. For each applied file, look for later modifications: `git log --diff-filter=M --follow -- "$f"`.

## Severity

| Finding | Severity |
|---|---|
| Body changed (`git diff --ignore-all-space <first-SHA>..HEAD` non-empty) | **BLOCKER** |
| Whitespace-only change | WARNING |
| **Only a `--rollback` line changed** | INFO — Liquibase checksums the changeset body, not the rollback section, so this does not break the deploy |
| An existing `include:` **removed** from `db.changelog-master.yaml` | **BLOCKER** — Liquibase then treats that changeset as never-run |

Adding `include:` entries to the master changelog is the normal flow and is never flagged; only deletions and reorderings are.

## Fix

Restore the file (`git checkout <first-SHA> -- <file>`), then write a **new** `V<N+1>__<verb>-<thing>.sql` carrying the intended change with its own `--changeset` and `--rollback`, and register it in the master changelog.

**Never `--clearCheckSums` in a shared environment** — it is an emergency escape hatch that erases audit history.

This skill does not auto-clear. If a flagged changeset genuinely has not reached any environment and the team agreed to amend it, the calling agent must say so explicitly.
