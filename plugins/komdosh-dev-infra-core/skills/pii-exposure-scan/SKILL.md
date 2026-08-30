---
name: pii-exposure-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*), Bash(git log:*)
description: Fast grep-based scan for personal-data (PII) exposure across an infrastructure repo and its adjacent code — PII stores without encryption at rest, PII stores/buckets exposed publicly, raw PII in logs/spans/event schemas, prod PII copied into non-prod, unbounded retention on PII stores, committed data dumps/fixtures containing PII, and jurisdiction commingling (EU + RU personal data in one region). Returns findings classified BLOCKER/WARNING/INFO with file:line, referencing rules/pii-data-protection.md. Read-only — never prints the personal data itself, only its location and class. The cheap preflight the data-protection-auditor runs first.
---

# PII Exposure Scan

The cheap preflight before `data-protection-auditor`. Follows `rules/pii-data-protection.md`. **Never echoes the personal data** — a finding names the location and the class.

## The finding is the combination, not the word

Grep a PII lexicon (identifiers, financial, special-category terms) against store, bucket, topic, and schema names — then **correlate**: a PII-named store **×** (encrypted? public? retention? region?). The mere presence of the word `email` is not a finding; an unencrypted store named `customers` is.

**Unprotected at rest** — a PII-named managed DB, disk, or bucket with no KMS → **BLOCKER** · publicly reachable or holding a public IP → **BLOCKER** · no retention or lifecycle rule → WARNING.

**Back doors** — raw identifier fields shipped into log aggregation → WARNING, **BLOCKER when it crosses a border** · PII field names in an event or Avro payload → WARNING (tokenise instead) · **committed dumps or fixtures with real-looking PII → BLOCKER** (route to `secrets-sentinel` if credentials are mixed in).

**Environment and residency** — non-prod pointing at or copying from a prod PII store → WARNING · a Russian-personal-data store outside `ru-central1` → WARNING, handed to the iac plugin's `verify-yc-resources` · **EU-subject and RU-subject data in one store or region with no documented lawful-transfer basis → BLOCKER**.

**Erasure** — a PII store with backups and no stated deletion or crypto-shred path → WARNING: erasure cannot reach the backups.

## Output

`file:line` · PII class · the missing control · the concrete impact, grouped by severity, with the count of values disclosed stated as **zero**.

**Name the families that came back clean** — a clean verdict needs evidence. Route: `data-protection-auditor` for the deep pass · `secrets-sentinel` for credentials · `verify-yc-resources` for residency.
