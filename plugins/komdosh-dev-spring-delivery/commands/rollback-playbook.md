# /rollback-playbook [version]

**Service track only.** For each migration in the release window, produces inverse SQL where mechanically possible or an explicit "forward-fix only" decision otherwise. Surfaces ENV variables and feature flags that must move atomically with the rollback.

Refuses on the library track — libraries don't roll back; they release a fix version.

## Steps

- [ ] **Step 1: Confirm track is service**

Run `read-service-context`. If `kind == library`, REFUSE:
```
This command applies to service-track projects only.
Library-track equivalent: cut a new patch version with the fix; consumers upgrade.
```

If track is ambiguous, ask the user to set `kind` in `service.yaml` or pass `--track=service`.

- [ ] **Step 2: Determine the release window**

If the user supplied a version, the window is `last_tag..vX.Y.Z`. If not, default to `last_tag..HEAD`.

```bash
git log "$last_tag..HEAD" --diff-filter=A --name-only \
  -- '*/db/changelog/V*.sql' | grep -E '/db/changelog/V.*\.sql$' | sort -u
```

- [ ] **Step 3: Invoke `produce-rollback-playbook` skill**

The skill reads each new changeset, classifies it into one of:

| Class | Rollback strategy |
|---|---|
| Mechanically reversible | Inverse DDL emitted in the playbook. |
| Reversible-with-data-loss | "Forward-fix only" — refuses to emit the inverse. Surfaces the data-loss reason and a sketch of the forward-fix migration. |
| Type-narrowing or NOT NULL tightening | "Forward-fix only" — re-widening the column requires a new migration applied as a forward fix. |

It also scans for feature flags / ENV vars that the release introduces (`@ConditionalOnProperty`, `@Value("${...}")`, `application.yaml` additions) and surfaces them as "must move with rollback."

- [ ] **Step 4: Write the playbook**

Output: `docs/release/playbooks/vX.Y.Z.md`

Format:

```markdown
# Rollback Playbook — vX.Y.Z

Generated: YYYY-MM-DD

## Migrations in this release

### V42__add-orders-table.sql
- Class: mechanically reversible
- Inverse:
  ```sql
  DROP TABLE IF EXISTS orders;
  ```

### V43__drop-legacy-status-column.sql
- Class: forward-fix only
- Reason: dropping a column destroys data. Rolling back requires re-creating the column AND restoring the data from a backup.
- If rollback fires:
  - Restore the most recent pre-deploy backup OR
  - Apply this corrective migration (sketch):
    ```sql
    ALTER TABLE orders ADD COLUMN legacy_status VARCHAR(32);
    -- backfill from audit log if present, else accept that legacy_status will be NULL for orders created during the failed window
    ```

## Feature flags / ENV vars

If rolling back vX.Y.Z, also flip:

- `FEATURE_BULK_ORDERS=false` — introduced in this release.
- `BULK_ORDERS_MAX_BATCH_SIZE` (env var) — remove; consumed by the bulk endpoint.

## ENV var changes

None.

## Smoke after rollback

After the previous version is back up, verify:
- [ ] `/actuator/health` returns 200.
- [ ] `/api/v1/orders` returns 200 on the smoke fixture.
- [ ] No 5xx spikes in the dashboard for 10 minutes.
```

- [ ] **Step 5: Report**

```
Rollback playbook: docs/release/playbooks/vX.Y.Z.md
  Migrations:           <total>
    Mechanically reversible: <count>
    Forward-fix only:        <count>  ← user must confirm awareness
  Feature flags affected:   <count>
  ENV var changes:          <count>
  Suggested commit:
    git add docs/release/playbooks/vX.Y.Z.md
    git commit -m "docs(release): rollback playbook for vX.Y.Z"
```

If any migration is "forward-fix only", PROMINENTLY flag it. The user MUST acknowledge before the release proceeds — `release-coordinator` reads the playbook before opening the release PR and surfaces these.
