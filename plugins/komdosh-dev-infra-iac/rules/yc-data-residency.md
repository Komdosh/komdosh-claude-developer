# Yandex Cloud Data Residency (152-FZ) & PII at Rest

Specialises infra-core's `rules/pii-data-protection.md` for the YC stack — read that first for the classification taxonomy and the two-regime overview.

> **Not legal advice** — engineering obligations; confirm with counsel or your DPO.

## Localization, concretely

152-FZ requires that recording, systematization, accumulation, storage, updating, and retrieval of **RU citizens' personal data** happen in databases **physically located in Russia**. `ru-central1` satisfies that.

In the Terraform you write:

- **Pin RU-personal-data stores to `ru-central1`** — managed clusters, disks, and buckets. A PII store provisioned outside Russia is a localization **BLOCKER**.
- **The primary store is what localization governs** — and **backups and replicas must stay in-region too**, because a cross-region backup re-exports the data.
- **Cross-border transfer comes *after* localization, never instead of it.** Transfer abroad is permitted once the in-Russia copy exists, subject to notification and the destination's protection level. It never licenses skipping the in-Russia store.

## PII-at-rest controls on YC

**KMS** on managed-service disks, buckets, and the state that references them — unencrypted PII at rest is a BLOCKER · **Lockbox** for every credential reaching a PII store · **private access**, no public IP, TLS enforced — a publicly reachable PII store is a BLOCKER · **least-privilege IAM** with no `editor`/`admin` on a PII data path · **backups in-region, encrypted, retention stated**, and reachable by erasure or crypto-shred · **Audit Trails**, which is what makes 152-FZ's 24h/72h breach timeline achievable at all.

## The divergence

**152-FZ pulls** RU-citizen data **into** `ru-central1`. **GDPR restricts** moving EU-subject data **to** Russia — no adequacy decision, so an EU→RU transfer needs SCCs with supplementary measures or a derogation, neither of which sustains routine storage.

**Therefore: do not commingle EU-subject and RU-citizen personal data in one `ru-central1` store.** Partition by jurisdiction, with a documented lawful basis for anything that does cross. **EU personal data in `ru-central1` with no transfer basis is a compliance BLOCKER to flag for legal review** — not a decision this plugin makes.

## What the reviewers check

PII-named stores pinned to `ru-central1` and KMS-encrypted · no public reach · backups in-region, encrypted, retention stated, `prevent_destroy` on the data cluster · least-privilege IAM on the data path · Audit Trails on · any EU+RU commingling flagged for legal review.
