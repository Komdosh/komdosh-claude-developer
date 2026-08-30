---
name: jooq-generation-freshness
allowed-tools: Grep, Glob, Read, Bash(find:*), Bash(stat:*)
description: Check whether jOOQ-generated classes (Tables, Records, Indexes, Keys) are stale relative to the latest Liquibase changeset. Saves "method does not exist on OrdersRecord" loops after a migration. Run after editing any V*.sql file, before backend-implementer references jOOQ types.
---

# jOOQ Generation Freshness

Stale generated code is the usual reason jOOQ "has no method for this column" — the column is in the changeset, the codegen hasn't re-run. Run after `/add-migration` and before referencing a newly-added jOOQ type.

## Method

1. **Locate the generated directory** — try `adapters/outbound/build/generated/sources/jooq`, `…/generated-src/jooq`, then `build/generated/sources/jooq`.
   - Absent on a fresh clone → report `NEVER RUN` and stop.
   - Absent despite a jOOQ dependency → BLOCKER, misconfigured codegen (`rules/gradle-build.md`).
2. **Compare mtimes** — newest generated file vs. the newest of (`V*.sql`, `db.changelog-master.yaml`). `stat -f '%m %N'` on macOS, `stat -c '%Y %n'` on Linux; try both.
3. Generated ≥ newest changeset → `FRESH`. Otherwise `STALE`, with the lag. Treat under 60s as clock skew.

Report the two files, their mtimes, the lag, and the suggested `./gradlew :adapters:outbound:generateJooq` (confirm the task name in `build.gradle.kts`).

**Never regenerate from this skill.** Testcontainers-backed codegen pulls an image and applies migrations — the calling agent decides whether to wait.

This is an mtime heuristic, not a schema diff: a comment-only changeset edit flags STALE. That false positive is cheap, since regeneration is idempotent. Repeat for each generated directory in a multi-generator service. Where generated classes are checked into git, use `git log -1 --format=%ct -- <dir>` instead of mtime.
