# /add-migration [description]

Add one Liquibase changeset. Reads the existing conventions, writes the changeset inline, registers it in the master changelog, and verifies. Touches only `adapters/outbound/src/main/resources/db/changelog/`.

See `rules/persistence.md` for the full Liquibase discipline.

## Steps

- [ ] **Step 1: Get the migration description**

If the user provided one, use it. Otherwise ask: "What schema change do you need? (e.g. add column X to table Y, create table Z)"

- [ ] **Step 2: Read the existing migrations for conventions**

```bash
ls adapters/outbound/src/main/resources/db/changelog/ | sort -V
```

Read the master changelog and the last two migration files:

```bash
cat adapters/outbound/src/main/resources/db/changelog/db.changelog-master.yaml
ls adapters/outbound/src/main/resources/db/changelog/ | grep -E '^V[0-9]+' | sort -V | tail -2 \
  | xargs -I{} cat adapters/outbound/src/main/resources/db/changelog/{}
```

Note the naming pattern, SQL style, and idempotency approach actually in use — mirror them rather than importing a different style.

- [ ] **Step 3: Run the `liquibase-changeset-immutability` skill**

Confirms no already-applied changeset has been edited. A checksum mismatch fails the next deploy at boot, so catch it here.

- [ ] **Step 4: Find the next version number**

```bash
ls adapters/outbound/src/main/resources/db/changelog/ | grep -E '^V[0-9]+' | sort -V | tail -1
```

The new file is `V<N+1>__<past-tense-description>.sql` — two underscores, past-tense verb.

- [ ] **Step 5: Write the changeset**

Liquibase **formatted SQL**. The file MUST start with `--liquibase formatted sql` and every changeset MUST carry a `--changeset author:id` header. Without them Liquibase treats the file as opaque, recomputes its checksum on every deploy, and fails as soon as anyone touches it — even to edit a comment.

```sql
--liquibase formatted sql

--changeset team:V4-add-order-priority-column splitStatements:true
--comment: track priority on existing orders for the new SLA report
ALTER TABLE orders ADD COLUMN IF NOT EXISTS priority VARCHAR(20);
CREATE INDEX IF NOT EXISTS idx_orders_priority ON orders (priority) WHERE priority IS NOT NULL;
--rollback ALTER TABLE orders DROP COLUMN IF EXISTS priority;
```

Rules:
- Every statement is idempotent (`IF NOT EXISTS`, `IF EXISTS`, `CREATE OR REPLACE`) so lower environments can re-run it.
- The `--changeset` id is unique within the file; use `V<N>-<slug>` to match the filename.
- Provide a `--rollback` line whenever the reversal is non-obvious. `--rollback empty` only when the change is genuinely irreversible (e.g. a backfill) — say so in the `--comment`.
- **Never modify an applied changeset.** To change behaviour, add a new one.
- No `DROP TABLE`/`DROP COLUMN` without a data-retention note in the `--comment` and a matching `--rollback`.
- A new `NOT NULL` column on an existing table needs a `DEFAULT`, or must be split across changesets: add nullable → backfill → set NOT NULL.

- [ ] **Step 6: Register it in `db.changelog-master.yaml`**

```yaml
  - include:
      file: db/changelog/V4__add-order-priority-column.sql
      relativeToChangelogFile: true
```

Confirm the `include` count increased by exactly one.

- [ ] **Step 7: Verify**

```bash
./gradlew :boot:compileKotlin 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`. Then run the `jooq-generation-freshness` skill — a new changeset means the generated jOOQ classes are now stale, and referencing them before regeneration produces "method does not exist" loops.

- [ ] **Step 8: Report**

State the file created, version number, SQL applied, master YAML updated, and jOOQ freshness verdict.
