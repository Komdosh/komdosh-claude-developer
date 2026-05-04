# Avro Schema Rules

Rules for authoring `.avsc` (and `.avdl`) files for events flowing through Kafka, Pulsar, Pub/Sub, or any registry-backed pipeline. The schema is the **wire contract** — once published, every change is observed by every consumer. Changes that look harmless ("just rename the field") cause silent decode failures in production.

This rule is loaded by every command and agent in `komdosh-dev-spring-avro`.

## Naming

| Element | Convention | Example |
|---|---|---|
| Record name | `PascalCase` + `V<n>` suffix on the major version | `OrderCreatedV1`, `PaymentAuthorisedV2` |
| Namespace | Kotlin package of the owning module + `.events.v<n>` | `com.acme.orders.events.v1` |
| Field name | `snake_case` | `event_id`, `occurred_at`, `promo_code` |
| Enum name | `PascalCase` (no `V<n>` suffix on enums; the enclosing record carries the version) | `Currency`, `OrderStatus` |
| Enum symbol | `SCREAMING_SNAKE_CASE`, including `UNKNOWN` for forward-compat | `USD`, `PENDING_PAYMENT`, `UNKNOWN` |

Keep the record name's `V<n>` and the topic's `.v<n>` in lockstep. `OrderCreatedV1` lives in `orders.created.v1`. When the major version bumps, BOTH bump.

## Required `doc`

Every record AND every field has a non-empty `doc` string. The audit command flags missing docs. The doc captures:

- For the record: what the event represents in business terms, the source of truth, the idempotency key.
- For a field: meaning, units (millis vs seconds, USD vs cents), source (producer's clock vs server-stamped), and whether it can be null/empty in practice.

A schema where 80% of fields have empty `doc` is a contract that no consumer can read without grepping the producer's source. The audit treats record-doc absence as BLOCKER and field-doc absence as WARNING because (a) records are rarer, and (b) record-level docs are read first by anyone trying to decide "should I subscribe to this?".

## Nullability and Defaults

Avro takes the default value from the **first branch** of a union. This makes the order matter:

```json
// CORRECT — T-first, default null
{ "name": "promo_code", "type": ["string", "null"], "default": null }

// WRONG — null-first; consumers must handle null even when always present
{ "name": "promo_code", "type": ["null", "string"], "default": null }
```

The audit treats null-first unions as a BLOCKER.

For non-null fields that need a default for backward-compat with older producers, supply an explicit `default` of the correct type:

```json
{ "name": "currency", "type": "string", "default": "USD" }
```

If a field is genuinely required and has no sensible default, do NOT add one — but understand that introducing the field then requires either a topic version bump or a coordinated producer-first deploy. Most "required" fields are actually "required after the cutover date" — supply a sentinel default and tighten in a later schema.

## Logical Types

| Domain | Type | Why |
|---|---|---|
| Instant / timestamp | `{ "type": "long", "logicalType": "timestamp-millis" }` | Generates `Instant` in Java/Kotlin (with `dateTimeLogicalType=JSR310`). Never use a raw `long` — strips timezone semantics. |
| Date (no time) | `{ "type": "int", "logicalType": "date" }` | Days since epoch. Generates `LocalDate`. |
| UUID | `{ "type": "string", "logicalType": "uuid" }` | Generates `java.util.UUID`. Use for any stable identifier. |
| Money / decimal | `{ "type": "bytes", "logicalType": "decimal", "precision": <p>, "scale": <s> }` | Generates `BigDecimal`. **Never** use `double` or `float` for money — IEEE 754 rounding bites. |
| Duration | `{ "type": "fixed", "size": 12, "logicalType": "duration" }` | Niche; document the unit clearly. |

The audit warns when a field name suggests a logical type but the schema uses a primitive (e.g. `*_at` field with raw `long`, `*_id` field with raw `string`).

## Enum vs String

Use an **enum** when the set of values is closed and changes go through a deploy:

- `Currency`: `[USD, EUR, GBP, UNKNOWN]` — closed, deploy-driven.
- `OrderStatus`: `[DRAFT, PLACED, SHIPPED, CANCELLED, UNKNOWN]` — closed.
- `Country`: probably an enum, but ISO-3166 has 250+ codes — an enum is fine if the producer guarantees ISO membership.

Use a **string** when values are open or user-supplied:

- `email`, `name`, `description` — open.
- `promo_code` — user-supplied.
- An ID that could be opaque to this service.

Every enum has a `default` symbol — usually `UNKNOWN`. Without it, a producer that adds a new symbol will crash old consumers. The default symbol receives any unknown ordinal during decode.

Enum symbols are stored by **ordinal**, not by name. This makes reordering them a breaking change (the audit treats it as BLOCKER) — even if the new order is "more sensible." Add new symbols at the end.

## Aliases on Rename

Renaming a field without `aliases` is a silent decode failure: old payloads have the old name, new readers don't recognise it, the field shows up as null/missing. ALWAYS add `aliases`:

```json
{ "name": "customer_id", "aliases": ["user_id", "buyer_id"], "type": {...}, "doc": "..." }
```

Multiple aliases stack — every name the field has ever had goes in the array. Once an alias is added, NEVER remove it (unless every consumer of every payload that used it has retired).

The audit checks git history: if a field's name changed in the last commit and the new schema lacks an `aliases` entry pointing at the old name, that's a BLOCKER.

## Evolution Semantics

| Change | BACKWARD | FORWARD | Verdict | Notes |
|---|---|---|---|---|
| Add optional field with `default` | ✅ | ✅ | **Safe-additive** — bump in place. |  |
| Add required field with `default` | ✅ | ❌ | **Borderline** — bump in place but coordinate consumer deploy. |  |
| Add required field without `default` | ❌ | ❌ | **Breaking** — version up. |  |
| Remove optional field | ✅ | ✅ | **Safe-additive**. |  |
| Remove required field | ❌ | ✅ | **Breaking-backward** — version up. |  |
| Rename WITH `aliases` | ✅ | ✅ | **Safe-additive**. |  |
| Rename WITHOUT `aliases` | ❌ | ❌ | **Breaking** — version up. |  |
| Change field type | depends | depends | Default to **Breaking** until verify-schema-compat confirms. Avro promotes a few pairs (int → long, float → double, string ↔ bytes) — but treat as breaking by default. |  |
| Default removal | ❌ | ✅ | **Breaking-backward**. |  |
| Add enum symbol WITH default | ✅ | ✅ | **Safe-additive**. |  |
| Add enum symbol WITHOUT default | ❌ | ❌ | **Breaking**. |  |
| Reorder enum symbols | ❌ | ❌ | **Breaking** — ordinals are persistent. |  |

Run [`verify-schema-compat`](../skills/verify-schema-compat/SKILL.md) before every change. A `BACKWARD` verdict from the registry's own algorithm is more authoritative than this table — the table is the developer's heuristic for code review.

When a change is breaking, [`/avro-evolve`](../commands/avro-evolve.md) produces a v<n+1> file alongside the existing schema. The old schema and old topic stay in production until every consumer has migrated. The schema and topic versions move together: never bump the schema's `V<n>` without bumping the topic's `.v<n>`.

## Forbidden Patterns

| # | Pattern | Why |
|---|---|---|
| 1 | Null-first union (`["null", "<type>"]`) | Avro takes default from first branch; forces every consumer to handle null even when value is always present. |
| 2 | Field with no `doc` | Documentation is the contract; without it, every consumer guesses. |
| 3 | Record with no `doc` | Subscribers can't tell what the event represents. |
| 4 | Money in `double` or `float` | IEEE 754 rounding silently corrupts amounts. Use `decimal`. |
| 5 | Timestamp in raw `long` (no `logicalType`) | Strips timezone semantics; generates a plain `Long`, not `Instant`. |
| 6 | ID field in raw `string` (no `logicalType=uuid`) | Generates `String`; loses type-safety, allows arbitrary content. |
| 7 | Enum without a `default` symbol | New symbol from a newer producer crashes old consumers. |
| 8 | Reordering enum symbols | Avro stores ordinals; reorder = silent value swap on existing payloads. |
| 9 | Rename without `aliases` | Old payloads decode as null/missing — silent data loss. |
| 10 | `Map<String, Any>`-shaped fields | No schema enforcement; defeats the purpose of using Avro. |
| 11 | Topic name embedded in the schema | Records don't carry transport identity; the topic constant lives in `Topics.kt` per `event-consumers.md`. |
| 12 | Schema in `domain/` or `application/` | Hexagonal violation; wire types are adapter-owned. |
| 13 | Hand-written DTO when a registry is configured | Drifts silently from the schema; the generated class is the single source of truth. |

## Where the schema file lives

| Direction | Path |
|---|---|
| Inbound (this service consumes) | `adapters/inbound/<consumer>/src/main/avro/<namespace-as-dirs>/<RecordName>V<n>.avsc` |
| Outbound (this service produces) | `adapters/outbound/<channel>/src/main/avro/<namespace-as-dirs>/<RecordName>V<n>.avsc` |

NEVER `domain/`, NEVER `application/`. The hexagonal rules in core forbid Spring/Kafka/Avro types in those layers; an `.avsc` file there is a contract violation even before the generator runs.

## See Also

- [`rules/avro-codegen.md`](avro-codegen.md) — Gradle wiring and where the generated DTO lands.
- [`rules/avro-registry.md`](avro-registry.md) — Confluent + Apicurio integration.
- [`komdosh-dev-spring-events/rules/event-consumers.md`](../../komdosh-dev-spring-events/rules/event-consumers.md) — topic naming, the consuming side, the "version the topic, not the message" rule.
