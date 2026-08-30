---
description: Add one Liquibase changeset — next version number, formatted SQL with rollback, registered in the master changelog, then jOOQ freshness checked.
argument-hint: "[schema change description]"
---

# /add-migration

Touches only `adapters/outbound/src/main/resources/db/changelog/`. Full discipline in `rules/persistence.md`.

1. **Read the master changelog and the last two changesets** — mirror the naming, SQL style, and idempotency approach actually in use rather than importing a different one.
2. Run `liquibase-changeset-immutability` **before writing** — a checksum mismatch fails the next deploy at boot, so catch an accidental edit here.
3. Next version from `ls … | grep -E '^V[0-9]+' | sort -V | tail -1`. New file is `V<N+1>__<past-tense-description>.sql`.
4. Write it:

```sql
--liquibase formatted sql

--changeset team:V4-add-order-priority-column splitStatements:true
--comment: track priority on existing orders for the new SLA report
ALTER TABLE orders ADD COLUMN IF NOT EXISTS priority VARCHAR(20);
--rollback ALTER TABLE orders DROP COLUMN IF EXISTS priority;
```

   - `--liquibase formatted sql` and a `--changeset author:id` header are **mandatory** — without them Liquibase treats the file as opaque and fails as soon as anyone touches it, even to edit a comment.
   - Every statement idempotent (`IF NOT EXISTS`, `CREATE OR REPLACE`) so lower environments can re-run it.
   - `--rollback` whenever the reversal isn't obvious; `--rollback empty` only for a genuinely irreversible change, explained in the `--comment`.
   - **A new `NOT NULL` column on an existing table needs a `DEFAULT`**, or three changesets: add nullable → backfill → set NOT NULL.
   - No `DROP TABLE`/`DROP COLUMN` without a data-retention note in the `--comment`.
5. Register it in `db.changelog-master.yaml` with `relativeToChangelogFile: true`; confirm the include count rose by exactly one.
6. `./gradlew :boot:compileKotlin`, then `jooq-generation-freshness` — the new changeset just made the generated classes stale.

Report the file, version, SQL, changelog update, and the jOOQ verdict.
