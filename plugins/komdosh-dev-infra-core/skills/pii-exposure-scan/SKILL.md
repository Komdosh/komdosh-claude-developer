---
name: pii-exposure-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*), Bash(git log:*)
description: Fast grep-based scan for personal-data (PII) exposure across an infrastructure repo and its adjacent code — PII stores without encryption at rest, PII stores/buckets exposed publicly, raw PII in logs/spans/event schemas, prod PII copied into non-prod, unbounded retention on PII stores, committed data dumps/fixtures containing PII, and jurisdiction commingling (EU + RU personal data in one region). Returns findings classified BLOCKER/WARNING/INFO with file:line, referencing rules/pii-data-protection.md. Read-only — never prints the personal data itself, only its location and class. The cheap preflight the data-protection-auditor runs first.
---

# PII Exposure Scan

A seconds-long sweep for the highest-signal personal-data exposure patterns, before the deeper `data-protection-auditor` pass or an apply. Follows `rules/pii-data-protection.md`. Read-only, and it **never echoes the personal data itself** — a finding names the location and the PII class, not the value.

Scope to the diff (`git diff <base>...HEAD`) for a change, or the tree for an audit. Track as a todo when invoked.

## What it scans for

### Unprotected PII at rest (BLOCKER/WARNING)
- Managed DB / disk / bucket that (by name/label/tag — `users`, `customers`, `accounts`, `profiles`, `payments`, `pii`) holds PII but has no KMS/encryption configured → BLOCKER.
- PII store with `public`/`0.0.0.0/0` reachability or a public IP → BLOCKER.
- PII store/bucket with no retention/lifecycle rule → WARNING (unbounded retention).

### PII in the back doors (BLOCKER/WARNING)
- Log/trace config or code shipping raw identifier fields (`email`, `phone`, `passport`, `ssn`, `card`, `pan`, `address`, `full_name`) into log aggregation → WARNING (BLOCKER if cross-border, see residency).
- PII field names in an event/topic/Avro schema payload → WARNING (should be tokenized/minimised).
- Committed data dumps or fixtures (`*.sql`, `*.csv`, `seed*`, `fixtures/`) containing real-looking PII → BLOCKER (route to `secrets-sentinel` if credentials are mixed in).

### Environment & residency (BLOCKER/WARNING)
- Non-prod config pointing at, or copying from, a prod PII store → WARNING.
- Region/zone mismatch for a Russian-personal-data store (not `ru-central1`) → WARNING (152-FZ localization — hand to the yandex plugin's `verify-yc-resources`).
- Signals of EU-subject and RU-subject data in the same store/region with no documented lawful-transfer basis → BLOCKER (the localization-vs-transfer divergence in `rules/pii-data-protection.md`).

### Erasure & lifecycle (WARNING)
- A PII store with backups but no stated deletion/crypto-shred path → WARNING (erasure can't reach backups).

## Method

1. Scope: diff for a change, glob the tree for an audit. Restrict to infra + config + schema + fixture files.
2. Build a PII-name lexicon (identifiers, financial, sensitive-category terms) and grep with `grep -nE`, tuned tight to limit noise.
3. Correlate: a PII-named store × (encryption? public? retention? region?) — the finding is the *combination*, not the mere presence of the word `email`.
4. For each hit: `file:line`, PII class, the control that's missing, concrete impact. **Never** capture the personal-data value.

## Output

```
PII EXPOSURE SCAN — <scope>  (<b> blocker, <w> warning, <i> info); 0 values disclosed

BLOCKER
- <file>:<line>  <PII class>  <missing control>  — <concrete impact>
WARNING
- <file>:<line>  <PII class>  <gap>  — <impact>
INFO
- <file>:<line>  — <note>

Clean families: <what came back clean>
Route: data-protection-auditor (deep pass) · secrets-sentinel (if credentials) · yandex/verify-yc-resources (residency)
```

State which families came back clean — a clean verdict needs evidence. Never print a personal-data value; reference location + class only.
