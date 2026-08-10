---
name: jooq-generation-freshness
allowed-tools: Grep, Glob, Read, Bash(find:*), Bash(stat:*)
description: Check whether jOOQ-generated classes (Tables, Records, Indexes, Keys) are stale relative to the latest Liquibase changeset. Saves "method does not exist on OrdersRecord" loops after a migration. Run after editing any V*.sql file, before backend-implementer references jOOQ types.
---

# jOOQ Generation Freshness

## When to Use

- After `/add-migration` adds or modifies a Liquibase changeset.
- Before `backend-implementer` references a jOOQ-generated type for a column or table that may have just been added/changed.
- As part of `/verify-service` for any service using jOOQ codegen against Testcontainers Postgres.

This skill complements [`rules/persistence.md`](../../rules/persistence.md) (which mandates jOOQ DSL only, no raw SQL). Stale generated code is the most common reason jOOQ "doesn't have a method for this column" — the column exists in the changeset but the codegen has not been re-run.

## Output

```
jOOQ generation: <FRESH | STALE>
  Generated dir:        <path>
  Newest generated:     <file> (<mtime>)
  Newest changeset:     <file> (<mtime>)
  Lag:                  <H hours / D days> behind
  Suggested:            ./gradlew :adapters:outbound:generateJooq
```

If `STALE`, the calling agent must regenerate (or follow `rules/gradle-build.md` if the codegen is misconfigured) before referencing jOOQ types added by the recent changesets.

## Steps

- [ ] **Step 1: Locate the generated jOOQ directory**

The conventional locations (in order):

```bash
for d in adapters/outbound/build/generated/sources/jooq \
         adapters/outbound/build/generated-src/jooq \
         build/generated/sources/jooq; do
  [ -d "$d" ] && { echo "$d"; break; }
done
```

If no directory is found, two cases:

- **Fresh clone, never built**: state `jOOQ generation: NEVER RUN — run \`./gradlew :adapters:outbound:generateJooq\` first.` and exit.
- **Codegen disabled or misconfigured**: follow `rules/gradle-build.md` with `[BLOCKER] no jOOQ generated dir found despite jooq dependency in build.gradle.kts`.

- [ ] **Step 2: Find the newest generated file**

```bash
find <generated-dir> -name '*.kt' -o -name '*.java' \
  | xargs stat -f '%m %N' 2>/dev/null \
  || find <generated-dir> -name '*.kt' -o -name '*.java' \
       | xargs stat -c '%Y %n' 2>/dev/null \
  | sort -rn | head -1
```

(macOS uses `stat -f`, Linux uses `stat -c`. Try both.)

- [ ] **Step 3: Find the newest changeset file**

```bash
find . -path '*/db/changelog/V*.sql' \
  -not -path '*/build/*' \
  | xargs stat -f '%m %N' 2>/dev/null \
  || find . -path '*/db/changelog/V*.sql' \
       -not -path '*/build/*' \
       | xargs stat -c '%Y %n' 2>/dev/null \
  | sort -rn | head -1
```

Also check `db.changelog-master.yaml`:

```bash
find . -name 'db.changelog-master.yaml' -not -path '*/build/*' \
  -exec stat -f '%m %N' {} \; 2>/dev/null
```

The "newest changeset" is the maximum mtime across `V*.sql` files and the master changelog.

- [ ] **Step 4: Compare**

```text
if newest-generated-mtime >= newest-changeset-mtime: FRESH
else:                                                STALE (lag = changeset-mtime - generated-mtime)
```

A small clock-skew tolerance (60 seconds) is fine; treat lag below 60s as `FRESH (within tolerance)`.

- [ ] **Step 5: Report**

State the comparison in the format from the Output section.

If `STALE`, append:

```
Run:    ./gradlew :adapters:outbound:generateJooq
        (or the project's equivalent — check build.gradle.kts for the task name)

After regeneration, re-run this skill to confirm FRESH.
```

If the project uses Testcontainers-backed jOOQ codegen (the recommended pattern, where Postgres in Docker holds the schema temporarily), regeneration may take a few seconds to a minute on first run as the Postgres image is pulled.

- [ ] **Step 6: Do not auto-regenerate**

Do not invoke `./gradlew generateJooq` from this skill. Regeneration can be slow (Docker pulls, Liquibase apply, codegen pass) and the calling agent should decide whether to wait or escalate. State the suggested command and hand back control.

## Notes

- This skill is a heuristic based on mtimes — it does NOT compare schema content. A changeset that adds a comment-only change still bumps mtime, which would flag `STALE` even though no codegen output would differ. False positives here are cheap (a regenerate is idempotent).
- For multi-module services with multiple jOOQ generators (e.g. one per logical schema), repeat Steps 1–4 for each generated directory.
- Some teams check generated jOOQ classes into git. If `<generated-dir>` is tracked, Step 2 can be replaced with `git log -1 --format=%ct -- <generated-dir>` to use commit time instead of mtime.
