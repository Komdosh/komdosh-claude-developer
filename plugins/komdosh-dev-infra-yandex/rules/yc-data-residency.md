# Yandex Cloud Data Residency (152-FZ) & PII at Rest

Yandex Cloud is the natural home for Russian personal data because its regions are in Russia — which is exactly what **152-FZ localization** requires. This rule makes that concrete and connects it to the GDPR tension. It specialises infra-core's `rules/pii-data-protection.md` for the YC stack; read that first for the classification taxonomy and the two-regime overview.

> **Not legal advice** — engineering obligations, confirm specifics with counsel / your DPO.

## The 152-FZ localization rule, concretely

152-FZ (Art. 18.5, via 242-FZ) requires that the **recording, systematization, accumulation, storage, updating, and retrieval** of the personal data of citizens of the Russian Federation is done using databases **physically located in Russia**. Yandex Cloud's `ru-central1` region (zones `ru-central1-a` / `-b` / `-d`) satisfies the physical-location requirement.

What this means for the Terraform you write:

- **Pin Russian-personal-data stores to `ru-central1`.** Managed PostgreSQL/MySQL/Kafka/Redis/OpenSearch clusters, disks, and Object Storage buckets that hold RU-citizen PII declare `ru-central1` zones/region — never a non-RU region for the primary store. A PII store provisioned outside Russia is a localization BLOCKER.
- **The *primary* store is the one that matters.** Localization governs where RU personal data is first recorded and kept. Backups and replicas of that data must also stay in-region (a cross-region backup of a localized store re-exports the data).
- **Cross-border transfer comes *after* localization, not instead of it.** 152-FZ allows transfer abroad once the in-Russia copy exists, subject to notification/consent and the destination's protection level. It never permits skipping the in-Russia store.

## PII-at-rest controls on YC

Every YC store holding personal data (`rules/pii-data-protection.md` §controls, made specific):

- **KMS encryption** (`yandex_kms_symmetric_key`) on managed-service disks, Object Storage buckets, and the state that references them. Unencrypted PII at rest is a BLOCKER.
- **Lockbox** for the credentials that reach PII stores; never inline (infra-core `rules/secrets-hygiene.md`).
- **Private access** — no public IP on a PII database; reachable only from the app subnets/SG; TLS enforced. A publicly-reachable PII store is a BLOCKER.
- **Least-privilege IAM** — access to a PII store's service account/role is scoped and audited; no `editor`/`admin` on a PII data path (`rules/yc-security.md`).
- **Backups with residency + retention** — automated backups in-region, encrypted, with a stated retention that matches the data-protection retention policy; erasure must be able to reach or crypto-shred them.
- **Audit Trails** on the folder so reads/exports of PII are logged — this is what makes the 152-FZ breach-notification timeline (24h detection notice / 72h investigation results) achievable.

## The 152-FZ ⇄ GDPR divergence on YC

This is the architectural trap for a service with both RU and EU users:

- **152-FZ pulls** RU-citizen personal data **into** `ru-central1`.
- **GDPR restricts** moving EU-subject personal data **to** Russia — Russia has no EU adequacy decision, so an EU→RU transfer needs SCCs + supplementary measures or an Art. 49 derogation, which for routine storage is hard to sustain.

Therefore: **do not commingle EU-subject and RU-citizen personal data in one `ru-central1` store.** Partition by jurisdiction — RU personal data in `ru-central1`, EU-subject personal data in a GDPR-appropriate EU-based store (outside YC if YC has no compliant EU region for your case) — with a documented lawful basis for anything that does cross. An architecture that puts EU personal data into `ru-central1` without a transfer basis is a compliance BLOCKER to flag for legal review.

## What `yc-auditor` / `verify-yc-resources` check

- PII-named managed stores/buckets pinned to `ru-central1` (localization) and KMS-encrypted (at-rest).
- No public IP / `0.0.0.0/0` reach on a PII store.
- Backups in-region, encrypted, retention stated; `prevent_destroy` on the data cluster.
- Least-privilege IAM on the PII data path; Audit Trails enabled.
- Signals of EU + RU personal data in one region without a transfer basis → flag for legal review.
