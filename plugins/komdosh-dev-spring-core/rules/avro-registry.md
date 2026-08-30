# Avro Schema Registry

Confluent (default) or Apicurio. `discover-avro-toolchain` detects which is present.

## Subject naming

`TopicNameStrategy` (subject = `<topic>-value`) unless there is a specific reason: `RecordNameStrategy` when one record goes to many topics, `TopicRecordNameStrategy` when one topic carries many event types (usually a sign the topic should be split). Set it **explicitly** rather than relying on the client default — mixed strategies across topics is accidental drift, and it makes producers and consumers unable to find each other's schemas.

Apicurio's `artifact-resolver-strategy` is the same concept; `TopicIdStrategy` is the `TopicNameStrategy` equivalent.

## Compatibility mode

**`BACKWARD` by default** — it matches the consumers-deploy-first rollout most teams want for additive changes. `FULL` only when producers and consumers must evolve independently and the team holds to the stricter rule. `NONE` never.

Set the mode **per subject**, not only globally, so a deliberate relaxation on one subject doesn't quietly weaken every other one.

## Key properties

| Property (Confluent / Apicurio) | Value | Why |
|---|---|---|
| `specific.avro.reader` / `use-specific-avro-reader` | `true` | Otherwise deserialization falls back to `GenericRecord` and loses both generated-class type safety and logical types |
| `auto.register.schemas` / `auto-register` | see below | |
| `use.latest.version` / `find-latest` | `true` | Otherwise producers can pin a stale version forever while consumers see arbitrary mixes |

Credentials come from `${ENV}` placeholders. **Any literal token, password, or `user:password@` URL in committed YAML is a BLOCKER.**

### Apicurio version trap

The registry URL path differs by major version — `/apis/registry/v2` vs `/apis/registry/v3`. A wrong path returns 404 from the registry and **not a clear error from the serdes layer**, so the failure looks like something else entirely. Verify the deployed version rather than copying a path; the maven coordinates have also shifted between majors.

## Auto-register policy

`true` in local and CI (throwaway registries, fast iteration). **`false` in staging and prod** — there, schema registration is a deployment action: version-controlled, reviewed, deliberate, run from CI (`./gradlew registerSchemas` or `apicurio-registry-cli`). `auto.register.schemas: true` in `application-prod.yaml` is a BLOCKER, because one producer bug can register a malformed schema and corrupt every consumer.

## Promotion

Author the `.avsc` in the service repo → CI registers against **staging** and fails on a `verify-schema-compat` failure → merge registers against **prod** in the deploy pipeline → producer rolls out → consumers roll out. **Never register through the registry UI or from a laptop** — that is not reproducible and drifts from the repo silently.

## Forbidden patterns

| # | Pattern | Why |
|---|---|---|
| 1 | `auto.register.schemas: true` in production | A producer bug corrupts every consumer |
| 2 | Manual registration via the UI | Not reproducible, not reviewed, drifts |
| 3 | Credentials inlined in `application*.yaml` | Committed secrets get found and used |
| 4 | Mixed subject-naming strategies | Producers and consumers can't resolve each other |
| 5 | Compat mode `NONE` | Removes the only safety net |
| 6 | `specific.avro.reader: false` in prod | Falls back to `GenericRecord`; loses types and logical types |
| 7 | No latest-version resolution and no explicit pin | Producers stick on a stale schema |
| 8 | Skipping registry TLS validation | A misconfigured proxy sees every event in the clear |
