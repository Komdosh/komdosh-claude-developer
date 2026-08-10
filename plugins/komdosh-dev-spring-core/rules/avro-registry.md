# Avro Schema Registry Rules

How a Kotlin/Spring service integrates with a Schema Registry — Confluent (the default) or Apicurio. Covers subject-naming, compatibility mode, Spring Boot config, secret handling, and the auto-register policy.

This rule is loaded by [`/avro-new-event`](../commands/avro-new-event.md), [`/avro-audit`](../commands/avro-audit.md), and the [`avro-schema-author`](../agents/avro-schema-author.md) agent.

## Subject Naming Strategy

Three strategies, one default.

| Strategy | Subject for topic `orders.created.v1` | When to use |
|---|---|---|
| `TopicNameStrategy` (**default**) | `orders.created.v1-value` (and `-key` for the message key) | Single event type per topic. The 90% case. |
| `RecordNameStrategy` | `com.acme.orders.events.v1.OrderCreatedV1` | Same record published to multiple topics; subject is keyed by record FQN. |
| `TopicRecordNameStrategy` | `orders.created.v1-com.acme.orders.events.v1.OrderCreatedV1` | Multiple event types per topic (rare; usually a sign the topic should be split). |

Pick `TopicNameStrategy` unless there's a specific reason. The audit warns when a project mixes strategies across topics — that's almost always accidental drift.

Configure explicitly in Spring config (don't rely on the Kafka client default):

```yaml
spring:
  kafka:
    properties:
      value.subject.name.strategy: io.confluent.kafka.serializers.subject.TopicNameStrategy
      key.subject.name.strategy:   io.confluent.kafka.serializers.subject.TopicNameStrategy
```

## Compatibility Mode

The registry enforces compatibility per-subject. Available modes (Confluent):

| Mode | New schema can be added if... |
|---|---|
| `BACKWARD` (**default**) | Consumers using the new schema can read data produced under the old schema. |
| `BACKWARD_TRANSITIVE` | Same, transitively against ALL prior versions. |
| `FORWARD` | Consumers using the old schema can read data produced under the new schema. |
| `FORWARD_TRANSITIVE` | Same, transitively. |
| `FULL` | Both `BACKWARD` and `FORWARD` hold. |
| `FULL_TRANSITIVE` | Same, transitively. |
| `NONE` | No checks. Don't. |

Apicurio uses the same mode names with the same semantics.

**Pick `BACKWARD` as the default.** It matches the "consumers deploy first, producers second" rollout pattern that most teams want for additive changes. Switch to `FULL` only when the team needs producers and consumers to evolve independently AND has the discipline to hold to the stricter rule.

Set the mode at the **subject** level (not just globally), so a deliberate change to one subject doesn't accidentally weaken every other subject:

```bash
# Confluent — set per-subject compat at registration time (gradle-schema-registry-plugin)
schemaRegistry {
    config {
        subject("orders.created.v1-value", "BACKWARD")
    }
}
```

## Spring Boot config — Confluent

`application.yaml` for a service that consumes and produces Avro on Kafka with a Confluent registry:

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    properties:
      schema.registry.url: ${SCHEMA_REGISTRY_URL}
      basic.auth.credentials.source: USER_INFO
      basic.auth.user.info: ${SCHEMA_REGISTRY_USER}:${SCHEMA_REGISTRY_PASSWORD}
      specific.avro.reader: true                       # consumers deserialize into the generated SpecificRecord
      auto.register.schemas: false                     # production: never auto-register
      use.latest.version: true                         # producers use the latest registered version of the subject
      value.subject.name.strategy: io.confluent.kafka.serializers.subject.TopicNameStrategy

    consumer:
      key-deserializer:   org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
    producer:
      key-serializer:   org.apache.kafka.common.serialization.StringSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
```

For local dev (Testcontainers + a docker-compose registry), override in `application-local.yaml`:

```yaml
spring:
  kafka:
    properties:
      schema.registry.url: http://localhost:8081
      auto.register.schemas: true                      # local only — fine for dev
      basic.auth.credentials.source: ""                # no auth on the local registry
```

## Spring Boot config — Apicurio

Apicurio Registry has TWO active major versions and the URL path differs:

| Version | URL path | Notes |
|---|---|---|
| Apicurio Registry v2 | `http://<host>:8080/apis/registry/v2` | Stable; widely deployed. |
| Apicurio Registry v3 | `http://<host>:8080/apis/registry/v3` | Current; the Apicurio examples on GitHub now target v3. URL path changed from `/v2` → `/v3`. |

Verify which version your deployment runs (a wrong URL path returns 404 from the registry, NOT a clear error from the serdes layer — silent failures are common). Both versions expose Avro serdes under the `io.apicurio.registry.serde.avro` package; the maven coordinate has shifted between major versions, so check the version your project depends on rather than hardcoding it.

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    properties:
      # v3 path: /apis/registry/v3 — verify against your deployed Apicurio version
      apicurio.registry.url: ${APICURIO_REGISTRY_URL}
      apicurio.registry.auth.username: ${APICURIO_REGISTRY_USER}
      apicurio.registry.auth.password: ${APICURIO_REGISTRY_PASSWORD}
      apicurio.registry.auto-register: false
      apicurio.registry.find-latest: true
      apicurio.registry.use-specific-avro-reader: true
      apicurio.registry.artifact-resolver-strategy: io.apicurio.registry.serde.strategy.TopicIdStrategy
    consumer:
      value-deserializer: io.apicurio.registry.serde.avro.AvroKafkaDeserializer
    producer:
      value-serializer:   io.apicurio.registry.serde.avro.AvroKafkaSerializer
```

Apicurio's "artifact-resolver-strategy" plays the role Confluent's "subject-name-strategy" plays. `TopicIdStrategy` is the equivalent of `TopicNameStrategy`.

## Auto-Register Policy

The `auto.register.schemas` flag (Confluent) / `apicurio.registry.auto-register` (Apicurio) controls whether the producer registers a new schema on the fly when it sees one that isn't in the registry yet.

| Profile | Setting | Why |
|---|---|---|
| `local` / dev container | `true` | Fast iteration; the developer's local registry is throwaway. |
| `test` (CI) | `true` | Tests against ephemeral registries should self-register. |
| `staging` | **`false`** | Catches drift between code and the deployed schema. |
| `prod` | **`false`** | Schema registration is a deployment action — version-controlled, peer-reviewed, deliberate. |

Production registration runs from CI as `./gradlew registerSchemas` (Confluent gradle-schema-registry-plugin) or via `apicurio-registry-cli`. The audit treats `auto.register.schemas: true` in `application-prod.yaml` as a BLOCKER.

## Secret Handling

Registry credentials are secrets. Source them from the environment via Spring `${...}` placeholders, NEVER inline them.

| BAD | GOOD |
|---|---|
| `basic.auth.user.info: alice:hunter2` | `basic.auth.user.info: ${SCHEMA_REGISTRY_USER}:${SCHEMA_REGISTRY_PASSWORD}` |
| `schema.registry.url: https://alice:hunter2@registry.acme.com` | `schema.registry.url: ${SCHEMA_REGISTRY_URL}` |
| Hard-coded API key in committed YAML | Sourced from k8s secret / vault / SSM |

The audit treats any literal token, password, or `user:password@` URL in committed YAML as a BLOCKER. Use the platform's secret manager (Kubernetes secrets, AWS SSM, HashiCorp Vault, etc.) and inject via env.

## Schema Promotion Across Environments

Rough flow:

1. Author the `.avsc` in the service repo.
2. CI on the feature branch registers the schema against the **staging** registry. If `verify-schema-compat` fails, the CI job fails.
3. PR merges to main → CI registers against **prod** registry as part of the deploy pipeline.
4. The producer rolls out (its image references the schema-registry-backed serializer).
5. Consumers roll out (they read the schema from the registry, not from a hardcoded class).

Never register schemas via the registry UI or the developer's laptop. The registry is part of the deployed system, not a per-developer notebook.

## Forbidden Patterns

| # | Pattern | Why |
|---|---|---|
| 1 | `auto.register.schemas: true` in production | A bug in the producer can register a malformed schema and corrupt every consumer. |
| 2 | Schemas registered manually via the UI | Not reproducible; not version-controlled; drifts silently from the repo. |
| 3 | Credentials inlined in `application*.yaml` | Committed secrets get found, leaked, and used. |
| 4 | Mixed subject-naming strategies across topics | Consumers and producers can't find each other's schemas; debugging is awful. |
| 5 | Compat mode set globally to `NONE` | Removes the only safety net; every change becomes a coin flip. |
| 6 | `specific.avro.reader: false` in production consumers | Forces deserialization to `GenericRecord`; loses generated-class type safety; loses logical types. |
| 7 | `use.latest.version: false` for producers AND no explicit version pin | Producers may use a stale schema version forever; consumers see arbitrary mixes. |
| 8 | Trusting the registry's TLS without certificate validation | A misconfigured intermediate proxy will see every event in the clear. |

## See Also

- [`rules/avro-schemas.md`](avro-schemas.md) — schema authoring and evolution semantics.
- [`rules/avro-codegen.md`](avro-codegen.md) — Gradle wiring and generated-DTO placement.
- [`komdosh-dev-spring-core/rules/event-consumers.md`](../../komdosh-dev-spring-core/rules/event-consumers.md) — the consuming side; topic naming.
- Confluent Schema Registry docs (verify current at runtime via context7 if the registry behaviour you depend on isn't covered here).
- Apicurio Registry docs (same — Apicurio's serdes coordinates have shifted between major versions).
