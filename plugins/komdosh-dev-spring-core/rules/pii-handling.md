# PII Handling (Application Layer)

Personal data — anything identifying a person (name, email, phone, national ID, address, precise location, financial or health data) — carries legal obligations the moment code touches it. This is the code-level discipline. Storage, residency, and erasure at the infrastructure layer are infra-core's `rules/pii-data-protection.md`.

> Engineering obligations, not legal advice. Confirm specifics with counsel/DPO.

## Classify at the type level

Wrap personal data in value classes whose **`toString()` redacts** (`"EmailAddress(***)"`). This is the highest-leverage control available: it protects every `log.info("… $user")`, every exception message, and every `data class` that embeds the field. A raw `String email` has no such protection.

Mark PII-bearing types (`@Pii` annotation or marker interface) so scans and reviewers can find them. An unmarked field named `email`/`phone`/`ssn`/`passport`/`card` is PII until proven otherwise.

## Never log, trace, or tag raw PII

Logs are not access-controlled or residency-bound the way the database is, so PII there leaks widest. Log **surrogate identifiers** (opaque user/order IDs). Never a PII value in a span attribute or metric tag.

## Minimise, mask, tokenise

- Collect and carry only what the use case needs — don't pass a full `User` to something that needs an age band; don't persist a field never read.
- **Mask at the API boundary** (`j***@example.com`, `**** 4242`). Never return more PII than the caller is entitled to.
- Replace direct identifiers with tokens for downstream systems (analytics, events) that don't need the real value; keep the token↔value mapping in one guarded place.

## Special categories

Health, biometrics, and financial PANs get application- or column-level encryption **on top of** at-rest disk encryption — so a DB dump doesn't expose them, and so **crypto-shredding** (destroying the per-subject key) is a viable erasure path. Card data is PCI-DSS scope: tokenise via the payment provider, never store a raw PAN.

## PII in events is PII at rest

A topic retains its payloads and is read by many consumers, so an event carrying PII **is** a PII store — inheriting encryption, access, residency, and retention obligations. Prefer a tokenised reference (`userId`) and let each consumer resolve what it is entitled to. Embedding PII is a deliberate, documented decision, and a schema change that adds a PII field is a review flag.

## Subject rights, built in from day one

- **Erasure** (GDPR Art. 17 / 152-FZ) must reach *every* copy: primary row, replicas, caches, search indices, event streams, analytics. Where a store can't be surgically edited, crypto-shred. A soft-delete flag that leaves the data readable is not erasure.
- **Access & portability** (Art. 15/20) needs a per-subject data map designed up front, not an afterthought query.
- Record the lawful basis/consent where flows require it, and stop processing when it is withdrawn.
- Enforce a maximum retention age by scheduled purge.

Deletion and access endpoints are privileged operations and are protected as such.

`pii-safety-scan` flags: raw PII in log/trace statements, PII types without a redacting `toString()`, PII in event payloads or response DTOs without masking, and PII in span/metric tags.
