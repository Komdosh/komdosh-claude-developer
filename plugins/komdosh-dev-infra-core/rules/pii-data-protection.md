# PII & Data Protection (Infrastructure Layer)

When infrastructure stores, moves, backs up, or logs personal data, it inherits the obligations. Yandex-specific residency mechanics are the iac plugin's `rules/yc-data-residency.md`; app-layer discipline is the Spring suite's `rules/pii-handling.md`.

> **Not legal advice** — the engineering-relevant obligations of Russian **152-FZ** and the EU **GDPR**, so infrastructure defaults are compliant by construction. Confirm specifics with counsel or your DPO.

## Classify before you protect

| Class | Examples | Baseline |
|---|---|---|
| **Direct identifiers** | name, email, phone, national ID, login | encrypt at rest and in transit; least privilege; audit reads |
| **Quasi-identifiers** | DOB, postcode, device ID, IP, precise location | same — **dangerous in combination** (re-identification) |
| **Special categories** | health, biometrics, religion, orientation, politics | highest bar: field-level encryption, explicit consent, strict access, tighter retention |
| **Financial** | card PAN, bank account, transaction detail | PCI-DSS scope; tokenise; never in logs; segregated store |
| **Non-PII** | aggregates, anonymised counts | standard controls — **verify the anonymisation is irreversible** |

Label every store and topic with its class. **An unlabelled store is audited as potentially-PII**, and the missing label is itself a finding.

## The six controls

1. **Encrypt at rest** with a customer-managed key — databases, disks, buckets, the secret store. Unencrypted PII at rest is a **BLOCKER**.
2. **Encrypt in transit** on every hop carrying PII.
3. **Least-privilege access.** "Who can read the users table" is a security boundary, not a convenience; broad or admin access to a PII store is a finding.
4. **Network isolation** — private, reachable only from the app tier. A PII store open to `0.0.0.0/0` is a **BLOCKER**.
5. **Residency** per the jurisdiction's law (below).
6. **Audit the data plane** — reads, writes, and exports of PII logged to immutable storage, so access is accountable and a breach is *detectable*.

## PII leaks through the back doors

The database is the obvious store; the leaks are elsewhere. Each of these **is** a PII store:

- **Logs and traces** — log aggregation is rarely access-controlled or residency-bound the way the database is.
- **Backups and snapshots** — same encryption, residency, retention, and deletion obligations as the source. A backup outliving the policy, or landing in another region, is a finding.
- **Event streams** — a topic retains its payloads and fans them out. Prefer tokenised references.
- **Object storage** — exports, dumps, uploaded documents. **A public PII bucket is a critical incident.**
- **Non-prod copies** — prod PII in dev spreads the blast radius to weaker controls. Use synthetic or masked data.

## Retention and erasure

- **A stated maximum age per store, enforced by lifecycle rules** — bucket lifecycle, topic retention, backup expiry, partition drop. No unbounded PII retention.
- **Erasure must reach every copy**: replicas, backups, caches, search indices, streams, analytics. Where a backup can't be surgically edited, **crypto-shred** the per-subject key.
- **Deletion is verifiable.** "We deleted the row, but it's in six months of backups and the warehouse" is not erasure.

## Two regimes, and where they diverge

| | Russia — 152-FZ | EU — GDPR |
|---|---|---|
| Core mandate | **Localization**: RU citizens' personal data recorded and stored in databases physically in Russia | **No localization**, but transfer to a country without an adequacy decision needs safeguards |
| Breach notice | **24h** of detection, investigation results within **72h** | **72h** to the supervisory authority; affected subjects without undue delay if high risk |
| Subject rights | access, correction, deletion, consent withdrawal | access, erasure, rectification, portability, restriction, objection |
| Lawful basis | consent-centric, with statutory exceptions | six bases; special categories need additional conditions |

**The load-bearing divergence:** 152-FZ *pulls* Russian personal data into Russia, while GDPR makes moving EU personal data *to* Russia hard — Russia has no adequacy decision. A service with both user bases therefore usually needs **jurisdiction-partitioned stores**, not one commingled global store. Design the data topology around this before it becomes a migration, and **flag any architecture commingling EU and RU personal data in one region without a documented lawful-transfer basis.**

## Severity

**BLOCKER** — unencrypted PII at rest · a PII store open to the internet · prod PII in a public bucket or in cross-border logs · commingled EU+RU data with no transfer basis · **no way to execute erasure at all**.
**WARNING** — over-broad access · unbounded or unstated retention · PII in an event payload without justification · prod PII in a weakly-controlled non-prod environment · missing data-plane audit.
**INFO** — an unlabelled store that turns out non-PII · a tightening opportunity.
