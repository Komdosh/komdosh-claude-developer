---
description: Audit how infrastructure handles personal data — classification, encryption at rest/in transit, access, network isolation, backups/logs/events, retention & erasure, and 152-FZ vs GDPR residency/transfer — classified BLOCKER/WARNING/INFO. Read-only; never prints the data.
argument-hint: [--path=<dir>] [--diff=<base>]
---

Invoke the `data-protection-auditor` agent to audit the infrastructure's personal-data handling.

- Default scope is the whole repo (or the `--path=` subtree); `--diff=<base>` narrows to a change.

The agent runs `discover-infra-context` and `pii-exposure-scan`, classifies the PII-bearing stores/buckets/topics/logs, then audits the controls per store (encryption at rest via KMS, TLS in transit, least-privilege access, network isolation), the back doors (PII in backups, logs/traces, event payloads, object storage, non-prod copies), the lifecycle (retention enforcement, erasure reachability including backups), and the two-regime posture (Russian-personal-data localization in `ru-central1`; the GDPR-vs-152-FZ localization-vs-transfer divergence; breach-detection audit trails).

Output is a BLOCKER/WARNING/INFO report with file:line and the concrete obligation — and **it never prints the personal data itself**, only its location and class. It surfaces engineering gaps against the law, not a legal determination. Residency specifics route to the iac plugin's `/yc-audit`, credential leaks to `/secrets-audit`, and app-layer PII-in-code to the Spring suite's `/pii-leakage-check`. Read-only — fixes route to the author agents.
