---
name: discover-avro-toolchain
user-invocable: false
description: "Detects which Avro code-generation plugin and which Schema Registry SDK are on the classpath of the current service. Returns a structured verdict — toolchain (davidmc24 / Confluent / avro4k / none), registry (Confluent / Apicurio / none), and recommended default if nothing is configured. Read-only. Run before any /avro-* command and from the avro-schema-author agent."
---

# Discover Avro Toolchain

Read-only detection, run before any Avro work. **Detect, then report — never assume a toolchain, and never edit Gradle** (that is delegated to `rules/gradle-build.md`). "No Avro setup" is a valid verdict, not a failure.

## Detect

Grep `*.gradle.kts`, `*.gradle`, and `libs.versions.toml` (excluding `build/`, `.gradle/`), including `buildSrc/` and the parent `settings.gradle.kts`:

| Target | Pattern |
|---|---|
| Codegen plugin | `davidmc24` · `kafka-schema-registry-gradle-plugin` · `avro4k`/`avrohugger` |
| Registry SDK | `io.confluent:kafka-avro-serializer`/`kafka-schema-registry-client` · `io.apicurio:apicurio-registry-serdes-avro-serde` |
| Spring config | `schema.registry.url`, `specific.avro.reader` · `apicurio.registry.url`, `apicurio.registry.auto-register` (in `*.yaml`/`*.properties`, capture file:line per profile) |
| Existing schemas | `find … \( -name '*.avsc' -o -name '*.avdl' \)`, grouped by owning module, with each file's `namespace` |

**Report all matches, not the first.** A project mixing davidmc24 (production `SpecificRecord`) with avro4k (test DTOs) is legitimate — the recommendation follows whatever produces the production DTOs. Both registry SDKs present is a WARNING: two registries, verify it's intentional. A private fork under a different group id reports as `custom` with its file:line so the caller can ask.

## Verdict

Emit JSON the caller can parse — `toolchain` (primary, version, config file:line, alternates), `registry` (vendor, coordinates, config files, URL per profile), `schemas` (count, files, namespaces), and `recommendation` (null when a toolchain exists) — plus a one-paragraph summary.

With no plugin configured, recommend `com.github.davidmc24.gradle.plugin.avro` (widest use; emits `SpecificRecord` that Kotlin consumes cleanly) and name the registry SDK matching the deployment target.

Schemas present but no registry SDK is **local-only codegen** — valid for file-system schema sharing, but worth flagging.
