# /add-migration [description]

Add a new Liquibase database migration. Reads existing conventions, invokes migration-writer with the next version number, and verifies the changeset is registered.

## Steps

- [ ] **Step 1: Get the migration description**

If the user provided a description, use it.
If not, ask: "What schema change do you need? (e.g., add column X to table Y, create table Z)"

- [ ] **Step 2: Read existing migrations for conventions**

```bash
ls adapters/outbound/src/main/resources/db/changelog/ | sort -V
```

Read the last 1-2 migration files:
```bash
ls adapters/outbound/src/main/resources/db/changelog/ | grep -E '^V[0-9]+' | sort -V | tail -2 \
  | xargs -I{} cat adapters/outbound/src/main/resources/db/changelog/{}
```

Note: naming pattern, SQL style, idempotency approach used.

- [ ] **Step 3: Find the next version number**

```bash
ls adapters/outbound/src/main/resources/db/changelog/ | grep -E '^V[0-9]+' | sort -V | tail -1
```

The next file uses N+1.

- [ ] **Step 4: Invoke migration-writer**

Pass to `migration-writer`:
- The schema change description
- The next version number (N+1)
- The naming and SQL conventions observed in Step 2

- [ ] **Step 5: Verify the changeset is registered**

```bash
grep -c "include" adapters/outbound/src/main/resources/db/changelog/db.changelog-master.yaml
```

Confirm the count increased by 1 compared to before this command ran.

- [ ] **Step 6: Run verification**

```bash
./gradlew :boot:compileKotlin 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Report**

State: file created, version number, SQL applied, master YAML updated.
