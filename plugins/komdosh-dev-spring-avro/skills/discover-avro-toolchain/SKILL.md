---
name: discover-avro-toolchain
description: "Detects which Avro code-generation plugin and which Schema Registry SDK are on the classpath of the current service. Returns a structured verdict — toolchain (davidmc24 / Confluent / avro4k / none), registry (Confluent / Apicurio / none), and recommended default if nothing is configured. Read-only. Run before any /avro-* command and from the avro-schema-author agent."
---

# Discover Avro Toolchain

## When to Use

Run this skill before any Avro-related work. The avro-schema-author agent and all three `/avro-*` commands invoke it. It is read-only and produces a structured JSON verdict that the calling command/agent uses to pick file paths, plugin defaults, and Spring config snippets.

## Do NOT

- Modify Gradle files. The verdict drives recommendations; any Gradle change is delegated to `build-expert` (core).
- Assume a specific toolchain. Detect, then report.
- Treat absence as failure — "no Avro setup" is a valid verdict.

## Steps

- [ ] **Step 1: Detect the Avro Gradle plugin**

```bash
# davidmc24 plugin (default recommendation)
grep -rE 'com\.github\.davidmc24\.gradle\.plugin\.avro|"com\.github\.davidmc24"|davidmc24' \
  --include='*.gradle.kts' --include='*.gradle' --include='libs.versions.toml' \
  --exclude-dir=build --exclude-dir=.gradle \
  . 2>/dev/null

# Confluent gradle-schema-registry-plugin (registry-aware tasks: registerSchemas, testSchemasTask)
grep -rE 'io\.confluent\.gradle-schema-registry|"com\.github\.imflog\.kafka-schema-registry-gradle-plugin"' \
  --include='*.gradle.kts' --include='*.gradle' --include='libs.versions.toml' \
  --exclude-dir=build --exclude-dir=.gradle \
  . 2>/dev/null

# avro4k / avrohugger (Kotlin-native data-class generation)
grep -rE 'avro4k|com\.github\.thake\.avro4k|com\.julianpeeters.*avrohugger|sbt-avrohugger' \
  --include='*.gradle.kts' --include='*.gradle' --include='libs.versions.toml' \
  --exclude-dir=build --exclude-dir=.gradle \
  . 2>/dev/null
```

If MORE than one plugin matches: surface ALL of them in the verdict — projects sometimes mix davidmc24 (for Java SpecificRecord) with avro4k (for Kotlin DTOs in tests). The recommendation defaults to whatever already produces the production DTOs.

- [ ] **Step 2: Detect the Schema Registry SDK**

```bash
# Confluent Schema Registry SDK
grep -rE 'io\.confluent:kafka-avro-serializer|io\.confluent:kafka-schema-registry-client|io\.confluent\.kafka\.schemaregistry' \
  --include='*.gradle.kts' --include='*.gradle' --include='libs.versions.toml' --include='*.kt' \
  --exclude-dir=build --exclude-dir=.gradle \
  . 2>/dev/null

# Apicurio Registry SDK
grep -rE 'io\.apicurio:apicurio-registry-serdes-avro-serde|io\.apicurio:apicurio-registry-client|apicurio\.registry' \
  --include='*.gradle.kts' --include='*.gradle' --include='libs.versions.toml' --include='*.kt' --include='*.yaml' --include='*.yml' \
  --exclude-dir=build --exclude-dir=.gradle \
  . 2>/dev/null
```

If both are present, the project is talking to two different registries — emit a WARNING in the verdict ("dual registry configuration; verify intentional").

- [ ] **Step 3: Detect existing schema files**

```bash
# .avsc and .avdl across all modules
find . -path ./build -prune -o -path ./.gradle -prune -o \
  \( -name '*.avsc' -o -name '*.avdl' \) -print 2>/dev/null
```

Group by module (the closest ancestor containing `build.gradle.kts`). Note the namespace from each file's `"namespace"` field. Useful for later steps that need to know "where do new schemas go?".

- [ ] **Step 4: Detect Spring Boot registry config**

```bash
# Confluent shape
grep -rnE 'schema\.registry\.url|spring\.kafka\.properties\.schema|specific\.avro\.reader' \
  --include='*.yaml' --include='*.yml' --include='*.properties' \
  --exclude-dir=build \
  . 2>/dev/null

# Apicurio shape
grep -rnE 'apicurio\.registry\.url|apicurio\.registry\.auto-register' \
  --include='*.yaml' --include='*.yml' --include='*.properties' \
  --exclude-dir=build \
  . 2>/dev/null
```

Capture file:line for every match. The audit and `/avro-evolve` commands read these.

- [ ] **Step 5: Emit the verdict**

```json
{
  "service": "<service-name>",
  "toolchain": {
    "primary": "davidmc24",
    "version": "1.9.1",
    "config_file": "build.gradle.kts:42",
    "alternates_present": []
  },
  "registry": {
    "vendor": "confluent",
    "sdk_coordinates": "io.confluent:kafka-avro-serializer:7.5.0",
    "config_files": [
      "boot/src/main/resources/application.yaml:18",
      "boot/src/main/resources/application-prod.yaml:6"
    ],
    "url_per_profile": {
      "default": "${SCHEMA_REGISTRY_URL:http://localhost:8081}",
      "prod":    "${SCHEMA_REGISTRY_URL}"
    }
  },
  "schemas": {
    "count": 4,
    "files": [
      "adapters/inbound/orders/src/main/avro/com/acme/orders/events/v1/OrderCreatedV1.avsc",
      "adapters/inbound/orders/src/main/avro/com/acme/orders/events/v1/OrderCancelledV1.avsc"
    ],
    "namespaces": ["com.acme.orders.events.v1"]
  },
  "recommendation": null
}
```

If no Avro plugin is configured, set `toolchain.primary = "none"` and populate `recommendation`:

```json
"recommendation": {
  "toolchain": "com.github.davidmc24.gradle.plugin.avro",
  "rationale": "Most widely used; emits Java SpecificRecord which is consumed cleanly from Kotlin.",
  "registry":  "io.confluent:kafka-avro-serializer (or io.apicurio:apicurio-registry-serdes-avro-serde if the deployment target uses Apicurio)",
  "next_step": "Delegate the Gradle edit to build-expert (core) and re-run this skill."
}
```

If no registry SDK is configured but the project has Avro schemas, surface "local-only codegen" — the project is using Avro as a contract format but not registering schemas. That's valid for some setups (file-system schema sharing) but worth flagging.

## Output

JSON verdict (above) + a one-paragraph markdown summary for the calling agent. The agent uses the verdict to:

- Decide where to place new `.avsc` files (matches existing `namespaces`).
- Decide which Gradle plugin's config block to recommend (matches `toolchain.primary`).
- Decide which Spring config snippet to surface in `/avro-new-event` (matches `registry.vendor`).
- Decide whether to emit a "no toolchain configured — delegate to build-expert" prompt.

## Notes

- The skill does not run Gradle. Detection is purely file-system + grep — fast, idempotent, safe.
- For projects using a `buildSrc/` convention plugin or a parent `settings.gradle.kts`, search those too.
- The skill ignores anything under `build/`, `.gradle/`, `node_modules/`, or `.idea/`.
- If the project uses a private fork of one of the plugins (different group ID), surface it as `toolchain.primary = "custom"` with the file:line so the calling agent can ask the user.
