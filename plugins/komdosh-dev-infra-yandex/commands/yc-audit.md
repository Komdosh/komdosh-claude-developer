---
description: Audit Yandex Cloud Terraform for security and reliability — IAM over-grants, SA-key exposure, Lockbox vs plaintext, network exposure, managed-DB HA/backups, regional vs zonal K8s masters — classified BLOCKER/WARNING/INFO. Read-only.
argument-hint: [--path=<dir>] [--diff=<base>]
---

Run a Yandex Cloud security-and-reliability audit with the `yc-auditor` agent.

- Default scope is the whole YC Terraform (or the `--path=` subtree); `--diff=<base>` narrows it to a change.

The agent runs `discover-yc-context` and `verify-yc-resources`, then audits:

- **IAM** — admin/editor/wildcard roles on service accounts (BLOCKER), cloud-scoped bindings, authoritative `iam_policy`, SA reuse.
- **Secrets/keys** — SA-key material in outputs/tfvars/committed `*-key.json` (BLOCKER → `secrets-sentinel`), `service_account_key_file` in-repo, secret literals vs Lockbox.
- **Network** — `0.0.0.0/0` on admin/DB ports, public IPs on data/internal resources, unrestricted public K8s API.
- **Reliability** — managed-DB HA topology + backup/retention, `prevent_destroy` coverage, zonal-vs-regional K8s master in prod, KMS encryption, Audit Trails.

Output is a BLOCKER/WARNING/INFO report with file:line and the concrete blast radius, plus the single highest-value fix. Read-only — never applies or edits; fixes route to `yc-provisioner`.
