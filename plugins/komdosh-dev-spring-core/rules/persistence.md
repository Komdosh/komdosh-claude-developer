# Persistence

## jOOQ

- Generated DSL only — **never a concatenated SQL string.** Codegen runs in the Gradle build against the Testcontainers database.
- **jOOQ `Record` types never leave `adapters/outbound/`.** Map to domain entities at the adapter boundary.
- `jooq-generation-freshness` flags generated classes that are stale relative to the newest changeset.

## Liquibase

Filename: `V<N>__<past-tense-verb>-<what>.sql` (two underscores), in `db/changelog/`.

Formatted SQL with an explicit changeset header, idempotent statements, and a rollback:

```sql
--liquibase formatted sql

--changeset team:V3-add-customer-email-column splitStatements:true
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_email VARCHAR(255);
--rollback ALTER TABLE orders DROP COLUMN IF EXISTS customer_email;
```

- **Register every file in `db.changelog-master.yaml`** — an unregistered changeset never runs. The `migration-register-reminder` hook catches this.
- **Never modify an applied changeset.** Liquibase tracks by checksum; a mismatch fails the next deploy at boot. Change behaviour by adding a changeset. `liquibase-changeset-immutability` catches this locally.

## Transactions and events

- **`TransactionalOperator.executeAndAwait`, never `@Transactional` on a `suspend fun`** — `rules/kotlin-coroutines.md` #3.
- Publishing an event alongside a DB write goes through an **outbox table written in the same transaction**, drained by a polling adapter. A broker cannot join a DB transaction, so any other ordering loses either the event or the row.
