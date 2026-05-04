# Avro Codegen Rules

How Avro schemas turn into compiled Java/Kotlin classes inside a Kotlin/Spring service. The default toolchain is **davidmc24/gradle-avro-plugin**; alternates (Confluent gradle-schema-registry-plugin, avro4k) are recognised but not the recommendation.

This rule is loaded by [`/avro-new-event`](../commands/avro-new-event.md), [`/avro-evolve`](../commands/avro-evolve.md), and [`/avro-audit`](../commands/avro-audit.md).

## davidmc24/gradle-avro-plugin (default)

In the module that owns the schema (typically an `adapters/inbound/<consumer>/` or `adapters/outbound/<channel>/` leaf module):

```kotlin
plugins {
    kotlin("jvm")
    id("com.github.davidmc24.gradle.plugin.avro") version "<version-from-libs.versions.toml>"
}

avro {
    // Generate java.time types (Instant, LocalDate, ...) instead of legacy Joda types.
    // Without this, fields with timestamp-millis become Joda DateTime — old, blocking, and
    // incompatible with kotlinx-coroutines context propagation.
    isCreateSetters.set(false)         // SpecificRecord builders + immutable fields; no setters
    fieldVisibility.set("PRIVATE")     // generated fields are private; access via getters
    stringType.set("String")           // not CharSequence — Kotlin interop
    enableDecimalLogicalType.set(true) // decimal -> BigDecimal, not ByteBuffer
    dateTimeLogicalType.set("JSR310")  // timestamps -> java.time.Instant
    outputCharacterEncoding.set("UTF-8")
}

dependencies {
    implementation("org.apache.avro:avro:<version>")
    // For Kafka with Confluent registry:
    implementation("io.confluent:kafka-avro-serializer:<version>")
}
```

Pin the version explicitly in `gradle/libs.versions.toml` — never use `+` or `latest.release`. The audit treats a floating version as a BLOCKER.

## Source paths

By default, davidmc24 reads from `src/main/avro/`. Keep the directory structure aligned with the schema's `namespace`:

```
adapters/inbound/orders/
├── build.gradle.kts
└── src/
    └── main/
        ├── avro/
        │   └── com/acme/orders/events/v1/
        │       ├── OrderCreatedV1.avsc
        │       └── OrderCancelledV1.avsc
        ├── kotlin/
        │   └── com/acme/orders/inbound/...
        └── resources/
```

A schema for `com.acme.orders.events.v1.OrderCreatedV1` lives at `src/main/avro/com/acme/orders/events/v1/OrderCreatedV1.avsc`. The directory mirrors the namespace exactly.

## Generated output

Output lands at `build/generated-main-avro-java/` by default. This directory:

- IS gitignored (already covered by the standard Gradle `.gitignore` for `build/`).
- Is NOT manually copied or committed anywhere else.
- Is automatically added to the Java/Kotlin source sets — generated classes are visible to Kotlin via their fully-qualified name.

The audit treats committed generated sources as a BLOCKER.

## Task ordering

The Avro generator runs as part of `compileJava` (and transitively `compileKotlin`). For multi-module setups where the consumer module references generated DTOs from another module, ensure the source set is exposed:

```kotlin
sourceSets {
    main {
        java.srcDirs("build/generated-main-avro-java")
    }
}

tasks.compileKotlin {
    dependsOn("generateAvroJava")
}
```

Modern davidmc24 versions wire this automatically — verify `./gradlew compileKotlin` triggers `generateAvroJava` without a manual `dependsOn`. If it doesn't, add the line above.

## Kotlin-from-Java interop

The davidmc24 plugin emits **Java** classes implementing `org.apache.avro.specific.SpecificRecord`. Consuming them from Kotlin works cleanly with one caveat: nullability.

```kotlin
import com.acme.orders.events.v1.OrderCreatedV1

class OrderCreatedHandler {
    suspend fun handle(event: OrderCreatedV1) {
        val orderId: UUID = event.orderId          // non-null in the schema → Kotlin sees UUID
        val promo: String? = event.promoCode       // optional in the schema → Kotlin sees String? (platform type, but the @Nullable on the getter helps)
        val amount: BigDecimal = event.totalAmount // decimal logical type → BigDecimal (because enableDecimalLogicalType=true)
        val occurredAt: Instant = event.occurredAt // timestamp-millis + JSR310 → Instant
    }
}
```

Optional fields generate as `@Nullable` Java getters. Kotlin treats them as **platform types** — declare the variable with an explicit nullable type (`String?`) to make the contract visible at the call site.

To construct a record from Kotlin, use the generated **builder** (do NOT use the all-args constructor — its argument order is positional and breaks on schema evolution):

```kotlin
val event = OrderCreatedV1.newBuilder()
    .setEventId(UUID.randomUUID())
    .setOccurredAt(Instant.now())
    .setOrderId(order.id.value)
    .setCustomerId(order.customerId.value)
    .setTotalAmount(order.total.amount)
    .setCurrency(Currency.USD)
    .setPromoCode(order.promoCode)
    .build()
```

The builder reads the schema, fills defaults for absent optional fields, and validates the result before returning.

## Alternative toolchains

### Confluent gradle-schema-registry-plugin

Use this when the project also wants registry-aware Gradle tasks: `downloadSchemas`, `registerSchemas`, `testSchemasTask`. It can run alongside davidmc24 (one generates classes, the other talks to the registry) — the audit recognises the combination.

```kotlin
plugins {
    id("com.github.imflog.kafka-schema-registry-gradle-plugin") version "<version>"
}

schemaRegistry {
    url.set(System.getenv("SCHEMA_REGISTRY_URL") ?: "http://localhost:8081")
    register {
        subject("orders.created.v1-value", "src/main/avro/.../OrderCreatedV1.avsc", "AVRO")
    }
    compatibility {
        subject("orders.created.v1-value", "src/main/avro/.../OrderCreatedV1.avsc", "AVRO")
    }
}
```

The `compatibility` block is what [`verify-schema-compat`](../skills/verify-schema-compat/SKILL.md) calls under the hood.

### avro4k (Kotlin-native data classes)

Generates Kotlin `data class`es with `kotlinx.serialization`-style annotations. More idiomatic Kotlin but smaller community and a different runtime than the Avro `SpecificRecord` API. Use it if the team has decided that the Kotlin-native shape outweighs the Java ecosystem (e.g. integrating with `kotlinx.serialization` JSON for HTTP and Avro for Kafka in a unified way).

```kotlin
plugins {
    id("com.github.thake.avro4k") version "<version>"
}
```

The schema files still follow [`rules/avro-schemas.md`](avro-schemas.md). The generated code shape differs but the wire format is identical.

### avrohugger (Scala/Kotlin) — not recommended

Mentioned for completeness. Mostly a Scala-ecosystem tool; in Kotlin/Spring projects, davidmc24 is the better default.

## What this rule does NOT cover

- Schema authoring — see [`rules/avro-schemas.md`](avro-schemas.md).
- Registry integration (subject naming, compat mode, Spring config) — see [`rules/avro-registry.md`](avro-registry.md).
- Consumer wiring — see [`komdosh-dev-spring-events/rules/event-consumers.md`](../../komdosh-dev-spring-events/rules/event-consumers.md).

## Audit Checklist (codegen)

The [`/avro-audit`](../commands/avro-audit.md) command runs these checks:

- [ ] Avro plugin pinned to an explicit version (no `+`, no `latest.release`).
- [ ] `dateTimeLogicalType = "JSR310"` set (BLOCKER if Joda types are emitted).
- [ ] `enableDecimalLogicalType = true` set (WARNING — decimal as `ByteBuffer` is a footgun).
- [ ] `stringType = "String"` (not `CharSequence`) for Kotlin interop.
- [ ] `build/generated-main-avro-java/` is gitignored and NOT in `git ls-files` output.
- [ ] Generated DTOs are referenced only from `adapters/*/dto/`, never from `domain/` or `application/`.
- [ ] `compileKotlin` (or `compileJava`) triggers `generateAvroJava` — verified by running it on a clean build dir.

## Precedent

The "generated code is a single source of truth" pattern parallels `komdosh-dev-spring-core`'s `jooq-generation-freshness` skill — same idea, different generator. If you're familiar with that skill, [`verify-schema-compat`](../skills/verify-schema-compat/SKILL.md) plays the analogous role for Avro.
