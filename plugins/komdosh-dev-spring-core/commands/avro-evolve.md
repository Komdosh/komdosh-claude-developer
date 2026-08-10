# /avro-evolve &lt;path-to-schema.avsc&gt; [--mode=auto|strict-backward|full]

Evolve an existing Avro schema with a compatibility check. Classifies the proposed change, recommends "bump in place" vs "version up", and produces the v2 file when the change is breaking.

## Steps

- [ ] **Step 1: Read the current schema**

Read `<path-to-schema.avsc>` and the previous version of the same file from git (`git show HEAD~1:<path>` if applicable, or pull the latest registered subject if a registry is configured).

If both are unavailable, this is not an evolution — route the user to `/avro-new-event` instead.

- [ ] **Step 2: Run `verify-schema-compat`**

Invoke [`verify-schema-compat`](../skills/verify-schema-compat/SKILL.md). The skill returns one of:

| Verdict | Meaning |
|---|---|
| `BACKWARD` | New schema can read data produced under the old schema. Consumers can deploy first, producers later. **Default Confluent compat mode.** |
| `FORWARD` | Old schema can read data produced under the new schema. Producers can deploy first, consumers later. |
| `FULL` | Both directions hold. Ideal but rare in practice. |
| `BREAKING` | Neither direction holds. A new topic version is required. |

- [ ] **Step 3: Classify the change**

Per [`rules/avro-schemas.md`](../rules/avro-schemas.md) evolution table:

| Change | Class |
|---|---|
| Add new optional field with `default` | **Safe-additive** — bump in place. `BACKWARD` and `FORWARD`-compat. |
| Add new required field with `default` | **Borderline** — `BACKWARD` only. Old consumers still read old payloads; new consumers fill the missing field with the default. |
| Add new required field WITHOUT default | **Breaking** — `BACKWARD`-incompat. New consumers cannot read old payloads. Version up. |
| Remove an optional field | **Safe-additive** — backward-compat. |
| Remove a required field | **Breaking** — version up. |
| Rename a field WITH `aliases` | **Safe-additive** — Avro resolves the alias on read. |
| Rename a field WITHOUT `aliases` | **Breaking** — old payloads fail to decode. |
| Change a field's type (even widening) | **Breaking** — version up. |
| Reorder enum symbols | **Breaking** — Avro stores enums by ordinal. Version up. |
| Add a new enum symbol AND the enum has a `default` | **Safe-additive** — old consumers map unknown symbols to `default`. |
| Add a new enum symbol WITHOUT `default` | **Breaking** — old consumers crash on the new symbol. |
| Remove `default: null` from an optional field | **Breaking** — old payloads with the field absent fail. |

If `--mode=full` is set, demote any `Borderline` to `Breaking` (require both directions to hold).

- [ ] **Step 4: Apply the change**

**Safe-additive**: edit the file in place. Increment the schema's `doc` to mention the change. Run codegen, verify the new generated class compiles. Run `verify-schema-compat` once more to confirm.

**Borderline**: same as safe-additive, but ALSO surface to the user that consumers older than this change will not see the new field. Recommend a phased rollout: deploy consumers first, then producers.

**Breaking**: do NOT edit the existing file. Produce a new file:

- New file path: `<same-dir>/<RecordName>V<n+1>.avsc`.
- New record name: `<RecordName>V<n+1>` (e.g. `OrderCreatedV2`).
- New namespace: bump the trailing version (`com.acme.orders.events.v1` → `com.acme.orders.events.v2`).
- New topic name: `<aggregate>.<verb>.v<n+1>` (`orders.created.v2`). Add the constant to `Topics.kt`.
- The OLD schema and topic stay in production until every consumer has migrated.

In a breaking-change PR description, list:
- Producers that need to start emitting v2 (and the cutover date).
- Consumers that need to read both v1 and v2 (and how long).
- The retirement date for v1 (when the old topic stops receiving traffic).

- [ ] **Step 5: Hand-offs**

- **Need a Gradle change** (e.g. add a new module for the v2 schema, or pin a new Avro version) → `rules/gradle-build.md`.
- **Producer needs to dual-emit** during the cutover → `backend-implementer`.
- **Consumer needs to read both v1 and v2** → `event-consumer-author` (events plugin). Mention the dual-version pattern from [`event-consumers.md`](../../komdosh-dev-spring-core/rules/event-consumers.md#schema-evolution).
- **Tests** for the new schema's round-trip and for cross-version compat → `test-writer`.

- [ ] **Step 6: Pre-commit checklist**

- [ ] `verify-schema-compat` verdict matches the classification.
- [ ] If breaking: v2 file created, v1 file untouched.
- [ ] `Topics.kt` updated only if a new topic version was introduced.
- [ ] Generated sources NOT committed.
- [ ] PR description names every consumer that has to be updated and the rollout order.
