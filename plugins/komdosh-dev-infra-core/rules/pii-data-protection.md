# PII & Data Protection (Infrastructure Layer)

Personal data is any information relating to an identifiable person. When infrastructure stores, moves, backs up, or logs it, the infrastructure inherits legal and ethical obligations. This is the canonical cross-infra rule; the Yandex-specific residency mechanics are in the yandex plugin's `rules/yc-data-residency.md`, and the app-layer code discipline is in the Spring suite's `rules/pii-handling.md`.

> **Not legal advice.** This encodes the *engineering-relevant* obligations of Russian **152-FZ** and the EU **GDPR** so infrastructure defaults are compliant-by-construction. Confirm specifics with counsel / your DPO — laws change and edge cases are fact-specific.

## Classify before you protect

You cannot protect what you haven't classified. Every data store, topic, bucket, and log stream carries a PII sensitivity, and it drives the controls:

| Class | Examples | Baseline control |
|---|---|---|
| **Direct identifiers** | name, email, phone, national ID, passport, account login | encrypt at rest + in transit; least-priv access; audit reads |
| **Quasi-identifiers** | DOB, postcode, device ID, IP, precise geolocation | same; dangerous in combination (re-identification) |
| **Special / sensitive categories** | health, biometrics, religion, sexual orientation, political views | **highest** bar: field-level encryption, explicit consent, strict access, extra retention limits |
| **Financial** | card PAN, bank account, transaction detail | PCI-DSS scope; tokenize; never in logs; segregated store |
| **Non-PII** | aggregated metrics, anonymised counts | standard controls; verify anonymisation is irreversible |

Label stores and topics with their PII class (a tag/label). An unlabelled store is treated as *potentially PII* until proven otherwise.

## The infrastructure controls

1. **Encrypt at rest** — every store holding PII uses managed encryption with a customer-managed key (KMS): managed databases, disks, Object Storage buckets, and the secret store itself. Unencrypted PII at rest is a BLOCKER.
2. **Encrypt in transit** — TLS on every hop that carries PII (DB connections, broker, internal service-to-service, ingress). No plaintext PII on the wire.
3. **Least-privilege access to PII** — access to a PII store is granted to the specific identity that needs it, scoped and audited. Broad/admin access to a PII database is a finding; treat "who can read the users table" as a security boundary, not a convenience.
4. **Network isolation** — PII stores are private (no public IP), reachable only from the app tier via a scoped security group / NetworkPolicy. A PII store exposed to `0.0.0.0/0` is a BLOCKER.
5. **Residency** — PII is stored in the jurisdiction its law requires (see §Two regimes). For the Yandex Cloud stack this means `ru-central1` for Russian personal data; the yandex plugin owns the specifics.
6. **Audit the data plane** — reads/writes/exports of PII are logged (cloud audit trails → immutable storage/SIEM), so access is accountable and a breach is detectable.

## PII leaks through the back doors

The database is the obvious store; the leaks are usually elsewhere. Treat each of these as a PII store:

- **Logs & traces** — PII in application logs, access logs, span attributes, or metric tags leaks into log aggregation, which is rarely access-controlled or residency-bound like the DB is. The app layer must not emit it (Spring `rules/observability.md` + `rules/pii-handling.md`); infra must not ship raw PII logs cross-border or retain them unbounded.
- **Backups & snapshots** — a backup of a PII store *is* PII: same encryption, same residency, same retention and deletion obligations. A backup that outlives the retention policy, or lands in a different region, is a finding.
- **Event streams** — PII in a Kafka/Redpanda topic payload is PII in flight and at rest (topic retention). Prefer tokenized references or minimised payloads; if a topic must carry PII, it inherits every control above.
- **Object storage** — exports, data dumps, uploaded documents (which may contain PII). Buckets holding PII are private + encrypted + residency-bound; a public PII bucket is a critical incident.
- **Non-prod environments** — copying prod PII into dev/staging spreads the blast radius to weaker controls. Use synthetic or masked data in lower environments; a raw-prod-PII copy in dev is a finding.

## Retention and deletion — the lifecycle obligation

Both regimes require that PII is kept no longer than necessary and can be deleted on a valid request. Infrastructure must make deletion *actually happen*:

- **Retention policy per store** — a stated maximum age, enforced by lifecycle rules (bucket lifecycle, topic retention, backup expiry, DB partition drop). No unbounded retention of PII.
- **Erasure reaches every copy** — a right-to-erasure (GDPR Art. 17) or deletion request must propagate to replicas, backups, caches, search indices, event streams, and analytics — not just the primary row. Where a backup cannot be surgically edited, **crypto-shredding** (destroy the per-subject encryption key) is the durable pattern.
- **Deletion is verifiable** — you can demonstrate a subject's data is gone. "We deleted the row but it's still in six months of backups and the analytics warehouse" is not erasure.

## Two regimes — 152-FZ and GDPR, and where they diverge

Both apply to a service with Russian and EU users. Encode both; the divergence is architectural, not cosmetic.

| Dimension | Russia — 152-FZ | EU — GDPR |
|---|---|---|
| Core mandate | **Localization**: personal data of RU citizens is *recorded and stored in databases physically located in Russia* (Yandex Cloud `ru-central1` satisfies this). | **No localization**, but transfer of EU-subject data to a third country lacking an adequacy decision needs safeguards (SCCs + supplementary measures) or a derogation. |
| Regulator / notification | Roskomnadzor: notify intent to process; breach notice **within 24h** of detection + investigation results **within 72h** (2022 amendments). | Supervisory authority: personal-data-breach notice **within 72h** (Art. 33); notify affected subjects without undue delay if high risk (Art. 34). |
| Subject rights | access, correction, deletion, withdrawal of consent. | access (15), erasure (17), rectification (16), portability (20), restriction (18), objection (21). |
| Lawful basis | consent-centric (with statutory exceptions). | six lawful bases (Art. 6); special categories need Art. 9 conditions. |

**The load-bearing divergence:** 152-FZ *pulls* Russian personal data **into** Russia; GDPR makes moving EU personal data **to** Russia hard (Russia has no EU adequacy decision). A service with both user bases therefore usually needs **jurisdiction-partitioned data stores** — RU-citizen PData in `ru-central1`, EU-subject PData in an EU region under GDPR-appropriate controls — not one commingled global store. Design the data topology around this before it becomes a migration. Flag any architecture that commingles EU and RU personal data in a single region as a compliance risk needing a documented lawful-transfer basis.

## Severity at the infra layer

- **BLOCKER** — unencrypted PII at rest; PII store open to the internet; raw prod PII in a public bucket or in cross-border logs; commingled EU+RU PData with no lawful-transfer basis; no way to execute erasure.
- **WARNING** — PII store with over-broad access; unbounded/unstated retention; PII in an event payload without justification; prod PII copied to a weakly-controlled non-prod env; missing data-plane audit.
- **INFO** — unlabelled store that turns out non-PII; a tightening opportunity (narrower key scope, shorter retention).
