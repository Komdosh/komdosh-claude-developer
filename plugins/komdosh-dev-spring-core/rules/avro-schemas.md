# Avro Schemas

The schema is the **wire contract**. Once published, every change is observed by every consumer, and the harmless-looking ones ("just rename the field") fail silently at decode rather than loudly at deploy.

## Naming

| Element | Convention |
|---|---|
| Record | `PascalCase` + `V<n>` — `OrderCreatedV1` |
| Namespace | owning module's package + `.events.v<n>` — `com.acme.orders.events.v1` |
| Field | `snake_case` |
| Enum | `PascalCase`, no version suffix (the record carries it) |
| Enum symbol | `SCREAMING_SNAKE_CASE`, including `UNKNOWN` |

**Record version and topic version move together**: `OrderCreatedV1` lives in `orders.created.v1`; bumping one bumps the other.

## Required `doc`

Every record and every field carries a non-empty `doc`. Missing record-doc is a BLOCKER, missing field-doc a WARNING.

A field's doc states meaning, **units** (millis vs seconds, USD vs cents), source (producer clock vs server-stamped), and whether it is null/empty in practice. A record's doc states what the event means in business terms and its idempotency key. Without them, a consumer has to read the producer's source to subscribe.

## Unions are T-first

Avro takes the default from the **first branch** of a union.

```json
{ "name": "promo_code", "type": ["string", "null"], "default": null }
```

A null-first union (`["null", "string"]`) is a BLOCKER — it forces every consumer to handle null even where the value is always present.

For a non-null field, supply an explicit `default` of the right type. Most "required" fields are really "required after the cutover" — ship a sentinel default and tighten later, or the field's introduction needs a topic bump or a coordinated producer-first deploy.

## Logical types

| Domain | Type | Why |
|---|---|---|
| Instant | `long` + `timestamp-millis` | Generates `Instant`; a raw `long` strips timezone semantics |
| Date | `int` + `date` | Generates `LocalDate` |
| Identifier | `string` + `uuid` | Generates `UUID`, not an arbitrary `String` |
| Money | `bytes` + `decimal(p,s)` | Generates `BigDecimal`. **Never `double`/`float` for money** — IEEE 754 rounding corrupts amounts silently |

A field named `*_at` on a raw `long`, or `*_id` on a raw `string`, is flagged.

## Enum vs string

Enum when the value set is closed and changes ship with a deploy (`OrderStatus`, `Currency`). String when values are open or user-supplied (`promo_code`, `email`).

- **Every enum has a `default` symbol**, usually `UNKNOWN` — it absorbs unknown ordinals from a newer producer. Without it, a producer adding a symbol crashes old consumers.
- **Symbols are stored by ordinal, not name.** Reordering them silently swaps the meaning of existing payloads — BLOCKER, even when the new order is more sensible. New symbols go at the end.

## Aliases on rename

Renaming without `aliases` is a silent decode failure: old payloads carry the old name, the new reader doesn't recognise it, the field arrives null.

```json
{ "name": "customer_id", "aliases": ["user_id"], "type": "…", "doc": "…" }
```

Aliases stack — every name the field has ever had stays in the array, and **an alias is never removed** while any payload that used it can still be read. A rename in the last commit with no matching alias is a BLOCKER.

## Evolution

| Change | Verdict |
|---|---|
| Add optional field with `default` · remove optional field · rename **with** `aliases` · add enum symbol **with** enum default | Safe-additive — bump in place |
| Add required field with `default` | Borderline — bump in place, coordinate the consumer deploy |
| Add required field without `default` · remove required field · rename without `aliases` · remove a default · add enum symbol without an enum default · reorder enum symbols | Breaking — version up |
| Change field type | Treat as breaking until `verify-schema-compat` says otherwise. Avro promotes a few pairs (int→long, float→double, string↔bytes); nothing else |

Run `verify-schema-compat` before every change — **the registry's own verdict outranks this table**, which is only the review heuristic. On a breaking change, `/avro-evolve` writes a `v<n+1>` file alongside the existing one; the old schema and topic stay live until every consumer has migrated.

## Forbidden patterns

| # | Pattern | Why |
|---|---|---|
| 1 | Null-first union | Default comes from the first branch |
| 2 | Field without `doc` | Every consumer then guesses |
| 3 | Record without `doc` | Subscribers can't tell what the event is |
| 4 | Money as `double`/`float` | Silent rounding corruption |
| 5 | Timestamp as raw `long` | Loses timezone semantics and the `Instant` mapping |
| 6 | Identifier as raw `string` | Loses type safety |
| 7 | Enum without a `default` symbol | A new symbol crashes old consumers |
| 8 | Reordering enum symbols | Ordinals are persistent — values swap |
| 9 | Rename without `aliases` | Silent data loss |
| 10 | `Map<String, Any>`-shaped fields | Defeats the point of Avro |
| 11 | Topic name embedded in the schema | Records carry no transport identity — `Topics.kt` owns it |
| 12 | `.avsc` under `domain/` or `application/` | Wire types are adapter-owned |
| 13 | Hand-written DTO where a registry exists | Drifts from the schema |

## Location

`adapters/inbound/<consumer>/src/main/avro/…` when consumed, `adapters/outbound/<channel>/src/main/avro/…` when produced. **Never `domain/` or `application/`** — an `.avsc` there violates `rules/hexagonal.md` before the generator even runs.
