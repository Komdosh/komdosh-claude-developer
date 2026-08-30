# Avro Codegen

Schemas → compiled classes. Default toolchain: **davidmc24/gradle-avro-plugin**. `discover-avro-toolchain` detects which is actually present before anything acts.

## Configuration

```kotlin
avro {
    isCreateSetters.set(false)               // immutable records; setters are a footgun on evolved schemas
    fieldVisibility.set("PRIVATE")
    stringType.set("String")                 // not CharSequence — Kotlin interop
    isEnableDecimalLogicalType.set(true)     // decimal -> BigDecimal, not ByteBuffer
}
```

Pin the plugin version in `libs.versions.toml`. A floating version (`+`, `latest.release`) is a BLOCKER.

## The Kotlin task-ordering trap

**From plugin 1.4.0 the Avro plugin no longer wires Kotlin compile tasks** (that would force a hard dependency on a Kotlin plugin version). Every module holding both `.avsc` files and Kotlin sources must wire it itself:

```kotlin
tasks.named("compileKotlin") { dependsOn("generateAvroJava") }
```

Without it the Kotlin compiler runs first and reports unresolved references to the generated classes — the classic "works in IntelliJ, fails in CI". Missing `dependsOn` in such a module is a BLOCKER.

## Layout

Schemas live in `src/main/avro/<namespace-as-directories>/<Record>V<n>.avsc` — the directory mirrors the namespace exactly. Output lands in `build/generated-main-avro-java/`, is gitignored, and is wired into the source set automatically. **Committed generated sources are a BLOCKER.**

## Consuming from Kotlin

The plugin emits Java `SpecificRecord` classes. Optional fields become `@Nullable` getters, which Kotlin sees as **platform types** — declare the variable with an explicit `String?` so the contract is visible at the call site.

**Construct records with the generated builder, never the all-args constructor** — the constructor is positional and silently breaks on evolution, while the builder fills defaults and validates.

## Alternatives

- **Confluent `kafka-schema-registry-gradle-plugin`** — registry-aware tasks (`registerSchemas`, `compatibility`); runs alongside davidmc24, one generating and one talking to the registry. Its `compatibility` block is what `verify-schema-compat` calls.
- **avro4k** — Kotlin-native `data class`es. Same wire format, same schema rules; a deliberate team choice, not the default.

## Audit checks

- Plugin version pinned; `isEnableDecimalLogicalType` not disabled; `stringType` not `CharSequence`.
- `build/generated-main-avro-java/` gitignored and absent from `git ls-files`.
- Generated DTOs referenced only from `adapters/*/`, never `domain/` or `application/`.
- `compileKotlin dependsOn generateAvroJava` wherever both file kinds exist.
- The `org.apache.avro:avro` runtime version matches what the generator emits against — a skew causes silent decode bugs.
