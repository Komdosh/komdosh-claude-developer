# /avro-audit [--scope=schemas|codegen|registry|all] [--module=&lt;glob&gt;]

Read-only audit of the service's Avro setup. Reports BLOCKER / WARNING / INFO findings across schema authoring, codegen wiring, and Schema Registry configuration. Writes `docs/avro/audit-YYYY-MM-DD.md`.

Distinct from `/avro-evolve` (which evaluates ONE schema change) — this audits the whole setup.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if it has not run this session. Refuse if `kind == library` (libraries don't own event topics).

- [ ] **Step 2: Run `discover-avro-toolchain`**

Capture the toolchain verdict. Three cases:

- **No Avro plugin and no `.avsc` files anywhere** → emit a single INFO ("no Avro setup detected — N/A") and exit. The audit has nothing to evaluate.
- **Plugin present, schemas present** → continue.
- **Plugin present, no schemas** → continue, but the schema-authoring section will be empty; this likely means the plugin is configured for a future event.

- [ ] **Step 3: Audit schemas**

For every `.avsc` (and `.avdl`) under any `src/main/avro/`:

| Rule | Severity if violated |
|---|---|
| Record has a non-empty `doc` | BLOCKER |
| Every field has a non-empty `doc` | WARNING |
| Optional fields are T-first (`["<type>", "null"]`) with `"default": null` | BLOCKER (null-first unions break Avro's default semantics) |
| No field uses `Map<String, Any>` or untyped `bytes` without a documented format | BLOCKER |
| Money fields use `decimal` (with explicit `precision`/`scale`) — never `double` or `float` | BLOCKER |
| Timestamp fields use `timestamp-millis` (or `timestamp-micros`) — never raw `long` | WARNING |
| ID fields use `uuid` logical type — never raw `string` (heuristic: field name ends in `_id` or `Id`) | WARNING |
| Enums have a `default` symbol | WARNING (without it, new producer symbols crash old consumers) |
| Enum symbols are SCREAMING_SNAKE_CASE | INFO |
| Record name carries a `V<n>` version suffix | INFO |
| Namespace matches the Kotlin package of the owning module | INFO |
| If a field has been renamed in git history, the new name has `aliases` | BLOCKER (silent decode failure for old payloads) |
| Schema is under `adapters/inbound/<consumer>/src/main/avro/...` (inbound) or `adapters/outbound/<channel>/src/main/avro/...` (outbound) — NOT `domain/`, NOT `application/` | BLOCKER (hexagonal violation) |
| File size under 1 MB (Confluent registry default limit) | WARNING |

- [ ] **Step 4: Audit codegen wiring**

| Rule | Severity if violated |
|---|---|
| Avro plugin pinned to an explicit version (no floating `+` or `latest.release`) in `gradle/libs.versions.toml` or `build.gradle.kts` | BLOCKER |
| `isEnableDecimalLogicalType` is NOT explicitly set to `false` (default in 1.4+ is `true`; flag only if explicitly disabled) | WARNING |
| `stringType` is NOT set to `"CharSequence"` (default `"String"` is right for Kotlin interop) | INFO |
| Avro runtime version (`org.apache.avro:avro`) matches the davidmc24 plugin's tested-against version (1.11.x for davidmc24 1.9.x) | WARNING if a 2-major skew (e.g. plugin 1.9 against avro 1.13) — silent decode bugs |
| `build/generated-main-avro-java/` (or equivalent) is in `.gitignore` and NOT in `git ls-files` output | BLOCKER |
| Generated DTOs are referenced from `adapters/*/dto/` only — never imported in `domain/` or `application/` | BLOCKER |
| If the module has BOTH `.avsc` files AND Kotlin sources, `compileKotlin` declares `dependsOn("generateAvroJava")` — davidmc24 1.4.0+ no longer auto-wires Kotlin | BLOCKER (else "works in IntelliJ, fails in CI") |

- [ ] **Step 5: Audit registry config**

If a registry SDK is on the classpath (`io.confluent:kafka-avro-serializer` or `io.apicurio:apicurio-registry-serdes-avro-serde`):

| Rule | Severity if violated |
|---|---|
| Subject-naming strategy is explicit in `application.yaml` (or the equivalent Spring config) | WARNING |
| Compatibility mode for each subject is set (default: `BACKWARD`) — verify via `gradle testSchemasTask` if available, else by inspecting registry config in CI scripts | WARNING |
| `auto.register.schemas=false` for production profiles (registration is a deliberate CI step) | BLOCKER if `true` in `application-prod.yaml` |
| Registry credentials sourced from environment variables / Spring `${...}` placeholders, NOT inlined | BLOCKER if a literal token, password, or API key appears in committed YAML |
| Registry URL points at HTTPS (production) or `localhost` / `kafka-schema-registry:8081` (dev) — never an http://prod-host with credentials in the URL | BLOCKER |
| `specific.avro.reader=true` (Confluent) or equivalent (Apicurio's `apicurio.registry.use-specific-avro-reader=true`) so consumers deserialize into the generated `SpecificRecord` class — not `GenericRecord` | WARNING |

- [ ] **Step 6: Write the report**

Output `docs/avro/audit-YYYY-MM-DD.md` with sections:

```markdown
# Avro audit — <service> — <date>

## Summary
| Category    | BLOCKER | WARNING | INFO |
|-------------|---------|---------|------|
| Schemas     |    2    |    5    |  3   |
| Codegen     |    0    |    1    |  0   |
| Registry    |    1    |    2    |  0   |

Posture: ATTENTION-NEEDED

## Findings
### Schemas
- **BLOCKER** — `adapters/inbound/orders/src/main/avro/.../OrderCreatedV1.avsc:14` — field `promo_code` uses null-first union `["null", "string"]`. Avro takes default from first branch; switch to `["string", "null"]` with `"default": null`. Rule: rules/avro-schemas.md#nullability.
- ...

### Codegen
- ...

### Registry
- ...
```

Posture verdict:
- **CLEAN** — zero BLOCKER and zero WARNING.
- **ATTENTION-NEEDED** — at least one WARNING, no BLOCKER.
- **BLOCKED FROM SHIP** — at least one BLOCKER.

- [ ] **Step 7: Surface the report**

Print the summary table and posture inline. Cite the report path. Highlight the single highest-impact finding.

- [ ] **Step 8: Suggest follow-ups**

| Posture | Suggestion |
|---|---|
| CLEAN | "Re-run before next release. No action needed." |
| ATTENTION-NEEDED | "Address WARNINGs at your discretion. Re-run after fixes." |
| BLOCKED FROM SHIP | "Address every BLOCKER before merging. For schema-shape BLOCKERs, route to `avro-schema-author`. For Gradle BLOCKERs, route to `build-expert`. For registry-config BLOCKERs (especially `auto.register.schemas=true` in prod), fix the YAML directly and re-run `/avro-audit`." |

This command never modifies code or config. It writes one Markdown report.
