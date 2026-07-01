# PII Handling (Application Layer)

Personal data — anything identifying a person (name, email, phone, national ID, address, precise location, financial or health data) — carries legal obligations the moment your code touches it. This rule is the code-level discipline; it pairs with `rules/observability.md` (no PII in logs/spans/metrics) and, where the infra suite is installed, infra-core's `rules/pii-data-protection.md` (the storage/residency/erasure obligations and the 152-FZ + GDPR overview).

> **Not legal advice** — engineering obligations that keep the code compliant-by-default. Confirm specifics with counsel / your DPO.

## Classify PII at the type level

Make PII visible in the type system so it can't be handled carelessly. Wrap personal data in value classes and treat their default rendering as a leak risk:

```kotlin
@JvmInline
value class EmailAddress(val value: String) {
    init { require(value.contains('@')) { "Invalid email" } }
    override fun toString() = "EmailAddress(***)"   // never render the value in logs/traces
}

@JvmInline
value class PhoneNumber(val value: String) {
    override fun toString() = "PhoneNumber(***)"
}
```

- Overriding `toString()` to redact is the cheapest, highest-leverage control: it protects every `log.info("... $user")`, every exception message, every `data class` that embeds the field. A raw `String email` field has no such protection.
- Tag PII-bearing domain types (a marker interface or annotation, e.g. `@Pii`) so scans and reviewers can find them. An unmarked field named `email`/`phone`/`ssn`/`passport`/`card` is treated as PII until proven otherwise.

## Never log or trace raw PII

MDC/logging is not access-controlled or residency-bound like the database is — PII there leaks widest.

```kotlin
// WRONG — leaks the address into log aggregation
log.info("Created order for {} at {}", user.email.value, user.address)

// CORRECT — log a stable non-PII identifier
log.info("Created order userId={} orderId={}", user.id.value, order.id.value)
```

- Log **surrogate identifiers** (opaque user/order IDs), never the personal data itself.
- Never put PII in span attributes or metric tags (`rules/observability.md` — also unbounded-cardinality).
- Redacted `toString()` (above) is the backstop when a PII object slips into a log statement.

## Minimise, mask, tokenise

- **Data minimisation** — collect and carry only the PII a use case needs. Don't pass a full `User` into a service that only needs an `age band`. Don't persist a field you never read.
- **Mask at the API boundary** — response DTOs expose masked PII where the full value isn't required (`j***@example.com`, `**** **** **** 4242`). Never return more PII than the caller is entitled to; never expose an internal store's raw row.
- **Tokenise / pseudonymise** — replace direct identifiers with tokens for downstream systems (analytics, events) that don't need the real value. Keep the token↔value mapping in one guarded place.

## Field-level encryption for sensitive categories

Special categories (health, biometrics, financial PANs) get application-level (or column-level) encryption on top of at-rest disk encryption, so a DB dump doesn't expose them and so **crypto-shredding** (destroying the per-subject key) is a viable erasure path. Card data is PCI-DSS scope — tokenise via the payment provider; never store a raw PAN.

## PII in events is PII in flight and at rest

An event payload (Kafka/Redpanda topic, Avro record) is retained on the topic and read by many consumers — treat it as a PII store.

- Prefer a **tokenised reference** (`userId`) over embedding raw PII in the event; let consumers resolve what they're entitled to.
- If an event must carry PII, that's a deliberate, documented decision — the topic inherits encryption/access/residency/retention obligations (infra-core `rules/pii-data-protection.md`), and a schema change adding a PII field is a review flag.

## Build for subject rights from day one

Both GDPR and 152-FZ give people rights over their data; the code must be able to honour them:

- **Erasure (GDPR Art. 17 / 152-FZ deletion)** — a delete request must reach every copy: primary row, replicas, caches, search indices, event streams, analytics. Where a store can't be surgically edited, crypto-shred. A soft-delete flag that leaves the PII readable is not erasure.
- **Access & portability (GDPR Art. 15 / 20)** — you can assemble and export everything you hold about a subject. Design a per-subject data map, not an afterthought query.
- **Consent & lawful basis** — record the basis/consent for processing where your flows require it, and stop processing when consent is withdrawn.
- **Retention** — enforce a maximum age (scheduled purge), don't keep PII "just in case."

Wire the write paths so these operations are mechanical, not archaeology. Deletion/access endpoints are protected like any privileged operation (`rules/api-conventions.md` + Spring Security).

## What `pii-safety-scan` catches

The fast preflight flags: raw PII field values in log/trace statements; PII-bearing types without a redacting `toString()`; PII in event payloads/DTO responses without masking; and PII in span/metric tags. Run it before declaring a change done, alongside `coroutine-safety-scan`.
