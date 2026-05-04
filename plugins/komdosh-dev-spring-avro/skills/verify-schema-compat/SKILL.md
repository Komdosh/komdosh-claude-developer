---
name: verify-schema-compat
description: "Compares a proposed Avro schema against its previous version (from git, or the live registry, or a referenced subject snapshot) and returns a structured compatibility verdict — BACKWARD / FORWARD / FULL / BREAKING — plus the changed fields and the rule each change violates. Read-only. Used by /avro-evolve and the avro-schema-author agent before any non-trivial schema change ships."
---

# Verify Schema Compat

## When to Use

Run before **every** schema change that is not a clean greenfield create. The verdict drives `/avro-evolve`'s "bump in place vs version up" decision and the `avro-schema-author` agent's pre-commit gate.

Read-only. No registry mutation, no Gradle execution beyond compatibility-check tasks.

## Do NOT

- Register a schema with the live registry. Registration is a deployment action; the skill only reads.
- "Fix" a breaking change automatically. Surface the verdict with the changed fields; let the calling agent decide whether to bump in place or version up.
- Treat a `BACKWARD` verdict as universal safety. Some changes (new required field with default) are technically `BACKWARD`-compat but still surprise consumers — the skill reports the class, not just the verdict.

## Steps

- [ ] **Step 1: Resolve the previous version**

In priority order:

1. If the project has the Confluent gradle-schema-registry-plugin AND a registry URL is reachable from the dev environment: pull the latest registered subject (`./gradlew downloadSchemas` or the equivalent CLI). Use the result as `previous`.
2. Else if the file exists in `git show HEAD:<path>`: use that as `previous`.
3. Else: this is not an evolution — exit with `verdict: NEW`, no comparison.

```bash
# Git-based previous-version retrieval
git show "HEAD:<path>" 2>/dev/null > /tmp/avro-previous-${BASH_PID}.avsc
```

- [ ] **Step 2: Pick the comparison engine**

Try in this order, fall back as available:

| Engine | When | How |
|---|---|---|
| **Confluent `testSchemasTask`** | gradle-schema-registry-plugin present | `./gradlew testSchemasTask -Dschema=<path>` — runs the registry's actual compat algorithm against the subject's compatibility mode. Most authoritative. |
| **`avro-tools compatibility`** | `avro-tools` jar/CLI on PATH | `java -jar avro-tools.jar compatibility <previous> <proposed>`. Authoritative for the four canonical compat modes. |
| **In-process via Apache Avro `SchemaCompatibility`** | Project already depends on `org.apache.avro:avro` | A small ad-hoc Kotlin script (or a one-off Gradle task) calling `SchemaCompatibility.checkReaderWriterCompatibility(reader, writer)`. The agent prints the script source rather than executing it from this skill — execution is the calling command's job. |
| **Structural diff** | Nothing else available | Apply the rule table from [`rules/avro-schemas.md#evolution-semantics`](../../rules/avro-schemas.md) field-by-field. Less rigorous than the registry's own algorithm but always available. |

- [ ] **Step 3: Classify each changed field**

Walk the diff between `previous` and `proposed`. For each field, classify:

| Class | Symptoms |
|---|---|
| `ADDED_OPTIONAL_WITH_DEFAULT` | New field, T-first union including null, `default: null`. Safe in both directions. |
| `ADDED_REQUIRED_WITH_DEFAULT` | New field, non-null type, has `default`. `BACKWARD`-compat (old data → reader fills default); not `FORWARD`. |
| `ADDED_REQUIRED_NO_DEFAULT` | New field, non-null type, no `default`. **BREAKING**. |
| `REMOVED_OPTIONAL` | Field present in `previous`, absent in `proposed`. Safe (reader ignores absent field if it has a default; producer stops emitting it). |
| `REMOVED_REQUIRED` | **BREAKING**. |
| `RENAMED_WITH_ALIAS` | Field name changed, new schema has `aliases: ["<old>"]`. Safe — Avro resolves on read. |
| `RENAMED_WITHOUT_ALIAS` | **BREAKING** — silent decode failure for old payloads. |
| `TYPE_CHANGED` | Even widening (`int` → `long`) — Avro promotes only some pairs. Default to **BREAKING** unless the diff engine confirms. |
| `DEFAULT_CHANGED` | Old payloads parse the same; new payloads under the old reader inherit the new default. Usually **BACKWARD**, occasionally surprising — surface it. |
| `DEFAULT_REMOVED` | A field that had a default no longer has one. **BREAKING**. |
| `ENUM_SYMBOL_ADDED_WITH_DEFAULT` | Enum had a `default` symbol → safe. |
| `ENUM_SYMBOL_ADDED_WITHOUT_DEFAULT` | **BREAKING** for old consumers. |
| `ENUM_SYMBOL_REORDERED` | **BREAKING** — Avro stores enums by ordinal. |
| `ENUM_SYMBOL_REMOVED` | **BREAKING**. |
| `DOC_CHANGED` | Doc-only change; no wire-format impact. INFO. |

- [ ] **Step 4: Roll up to a verdict**

```text
if (every change is in {ADDED_OPTIONAL_WITH_DEFAULT, REMOVED_OPTIONAL, RENAMED_WITH_ALIAS, ENUM_SYMBOL_ADDED_WITH_DEFAULT, DOC_CHANGED}):
    verdict = FULL
elif (no change is BREAKING) and (every change is in {…, ADDED_REQUIRED_WITH_DEFAULT, …}):
    verdict = BACKWARD
elif (no change is BREAKING) and the changes only restrict (REMOVED_OPTIONAL, etc.):
    verdict = FORWARD
elif (any change is BREAKING):
    verdict = BREAKING
```

- [ ] **Step 5: Emit the report**

```json
{
  "subject":   "orders.created.v1-value",
  "previous":  "git:HEAD:adapters/inbound/orders/.../OrderCreatedV1.avsc",
  "proposed":  "adapters/inbound/orders/.../OrderCreatedV1.avsc",
  "engine":    "confluent.testSchemasTask",
  "verdict":   "BACKWARD",
  "changes": [
    {
      "field":       "promo_code",
      "class":       "ADDED_OPTIONAL_WITH_DEFAULT",
      "old":         null,
      "new":         "[\"string\", \"null\"] default null",
      "note":        "Safe — old producers don't emit; reader fills with null."
    },
    {
      "field":       "currency",
      "class":       "ENUM_SYMBOL_ADDED_WITH_DEFAULT",
      "old":         "[USD, EUR, GBP, UNKNOWN]",
      "new":         "[USD, EUR, GBP, JPY, UNKNOWN]",
      "note":        "Safe — enum has default UNKNOWN; old consumers map JPY → UNKNOWN."
    }
  ],
  "advisory": "Verdict is BACKWARD. Bump in place is safe. If the registry's compat mode for this subject is FULL, additional verification is needed — check rules/avro-registry.md."
}
```

If `verdict == BREAKING`, the report MUST also include the recommended next-version filename and topic name, computed by bumping the trailing `V<n>` in the record name and the trailing `.v<n>` in the topic.

## Output

JSON verdict + markdown advisory. Consumed by `/avro-evolve` for the bump-in-place vs version-up decision, and by the `avro-schema-author` agent as a pre-commit gate.

## Notes

- For Confluent registries, the **subject's own compat mode** can be stricter than `BACKWARD` (e.g. `FULL`). The registry will reject a schema that this skill reports as `BACKWARD` if the subject is configured for `FULL`. Surface the subject's compat mode in the advisory.
- For Apicurio registries, the compat-mode names are slightly different (`BACKWARD`, `FORWARD`, `FULL`, `NONE`, plus `BACKWARD_TRANSITIVE`, `FORWARD_TRANSITIVE`, `FULL_TRANSITIVE`). The verdict mapping is the same.
- The skill does not auto-fix anything. A `BREAKING` verdict produces a recommendation to version up; the actual file creation is the calling command's job.
- If the project uses Avro IDL (`.avdl`) → schemas (`.avsc`) compile step, run `avro-tools idl2schemata` first to produce the `.avsc` to compare. The diff is always against compiled `.avsc`.
