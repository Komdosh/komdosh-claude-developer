---
description: Read-only audit of the service's whole Avro setup — schemas, codegen wiring, and registry config — classified BLOCKER/WARNING/INFO into docs/avro/.
argument-hint: "[--scope=schemas|codegen|registry|all] [--module=<glob>]"
---

# /avro-audit

Audits the whole setup; `/avro-evolve` evaluates one change. **Never modifies code or config** — it writes one report.

1. `read-service-context`. Refuse if `kind == library` — libraries don't own event topics.
2. `discover-avro-toolchain`. No plugin and no `.avsc` anywhere → emit one INFO ("no Avro setup — N/A") and exit.
3. **Schemas** — every `.avsc`/`.avdl` under any `src/main/avro/`, against `rules/avro-schemas.md`.
   - **BLOCKER**: missing record `doc` · null-first union · `Map<String,Any>` or undocumented untyped `bytes` · money as `double`/`float` · a git-history rename with no matching `aliases` · a schema under `domain/` or `application/`.
   - **WARNING**: missing field `doc` · raw `long` timestamp · raw `string` identifier (heuristic: name ends `_id`/`Id`) · enum with no `default` symbol · file over 1 MB (registry default limit).
   - **INFO**: symbol casing · missing `V<n>` suffix · namespace not matching the owning module.
4. **Codegen** — against `rules/avro-codegen.md`.
   - **BLOCKER**: floating plugin version · generated output tracked in git · generated DTOs imported from `domain`/`application` · a module with both `.avsc` and Kotlin sources missing `compileKotlin dependsOn generateAvroJava`.
   - **WARNING**: `isEnableDecimalLogicalType` explicitly disabled · a two-major skew between the Avro runtime and what the plugin generates against.
5. **Registry** (only if an SDK is present) — against `rules/avro-registry.md`.
   - **BLOCKER**: `auto.register.schemas: true` in a production profile · any literal credential in committed YAML · credentials embedded in a registry URL.
   - **WARNING**: subject-naming strategy not explicit · per-subject compat mode unset · specific-reader disabled.
6. Write `docs/avro/audit-YYYY-MM-DD.md` — a per-category count table, then findings as `**SEVERITY** — file:line — what and the concrete fix — rule reference`.

Posture: **CLEAN** (no BLOCKER, no WARNING) · **ATTENTION-NEEDED** (WARNINGs only) · **BLOCKED FROM SHIP** (any BLOCKER).

Print the table and posture inline, cite the report path, and highlight the single highest-impact finding. Route schema-shape blockers to `avro-schema-author`, Gradle blockers to `rules/gradle-build.md`, and registry-config blockers to a direct YAML fix and a re-run.
