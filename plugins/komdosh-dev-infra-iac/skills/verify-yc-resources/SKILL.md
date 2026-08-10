---
name: verify-yc-resources
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*)
description: Fast read-only security-reliability-and-data-protection check of Yandex Cloud Terraform — IAM over-grants (admin/editor/wildcard on a service account, cloud-scoped instead of folder-scoped, authoritative iam_policy), service-account key exposure, secrets in Lockbox vs plaintext, security groups open to 0.0.0.0/0 on admin/DB ports, public IPs on data/internal resources, missing KMS encryption, missing HA/backups on managed databases, zonal (non-HA) K8s masters in prod, and PII residency (152-FZ localization to ru-central1, unencrypted PII stores, EU+RU commingling vs GDPR transfer). Returns findings classified BLOCKER/WARNING/INFO with file:line. The YC preflight that runs before the deeper iac-reviewer pass. Read-only.
---

# Verify Yandex Cloud Resources

A quick grep-and-read pass over YC Terraform for the highest-signal security and reliability defects, before the deeper `iac-reviewer` review or an apply. Follows `rules/yc-security.md` and `rules/yc-managed-services.md`. Read-only. Track as a todo when invoked.

Scope to the diff (`git diff <base>...HEAD`) for a change, or the tree for an audit.

## Checks

### IAM (BLOCKER/WARNING)
- `yandex_resourcemanager_*_iam_member/binding` granting `admin`, `editor`, or a `*`/wildcard role **to a service account** → BLOCKER.
- Binding scoped to the **cloud** where a folder scope would do → WARNING.
- `yandex_resourcemanager_folder_iam_policy` (authoritative — replaces all bindings) → WARNING (lockout/foot-gun risk); prefer `iam_member`.
- One SA reused across cluster + CI + apps → WARNING.

### Service-account keys & secrets (BLOCKER)
- `yandex_iam_service_account_key` / `..._static_access_key` whose material lands in an output, a `.tfvars`, or a committed `*-key.json` → BLOCKER (route to `secrets-sentinel`).
- `service_account_key_file = "<path in repo>"` in the provider → BLOCKER.
- Secret literals (DB passwords, tokens) in `.tf`/`.tfvars` instead of Lockbox → BLOCKER.

### Network exposure (BLOCKER/WARNING)
- `yandex_vpc_security_group` ingress `v4_cidr_blocks = ["0.0.0.0/0"]` on an admin/DB port (22, 3389, 5432, 6379, 9200, 27017, 8443) → BLOCKER; on 443 for a public endpoint → WARNING (confirm intent).
- `nat = true` / a public IP on a managed DB, internal service, or node without a public role → WARNING.
- Public Managed K8s API endpoint without authorized-CIDR restriction → WARNING.

### Encryption & data protection (WARNING)
- `yandex_storage_bucket` / managed-service disk without KMS encryption → WARNING.
- Data bucket without versioning where it matters → INFO.

### Managed-service reliability (WARNING/BLOCKER)
- `yandex_mdb_*_cluster` with a single host / single zone in a prod env → WARNING (BLOCKER for prod-critical).
- Managed DB with no backup/retention configured → WARNING.
- Missing `prevent_destroy` on a managed data cluster the diff replaces → BLOCKER.
- `yandex_kubernetes_cluster` with a **zonal** master (`master { zonal {} }`) in prod instead of **regional** → WARNING.

### PII residency & data protection (BLOCKER/WARNING) — see `rules/yc-data-residency.md`
- A PII-named managed store/bucket (`users`, `customers`, `accounts`, `profiles`, `payments`, `pii`) NOT pinned to `ru-central1` when it holds Russian personal data → BLOCKER (152-FZ localization).
- PII-holding managed store/disk/bucket without KMS encryption → BLOCKER (unencrypted PII at rest).
- PII store with a public IP / `nat = true` / `0.0.0.0/0` reach → BLOCKER.
- PII store backups not in-region, unencrypted, or with no stated retention → WARNING.
- Signals of EU-subject + RU-citizen personal data in the same `ru-central1` store/region with no documented transfer basis → BLOCKER (flag for legal review — the 152-FZ-vs-GDPR divergence).
- Least-privilege gap on a PII data path (a service account with `editor`/`admin` reaching a PII store) → WARNING (BLOCKER if it's `admin`).

## Output

```
YC VERIFY — <scope>  (<b> blocker, <w> warning, <i> info)

BLOCKER
- <file>:<line>  <check>  — <concrete impact>
WARNING
- <file>:<line>  <check>  — <concrete impact>
INFO
- <file>:<line>  <check>  — <note>

Clean checks: <families that returned nothing>
```

State which checks came back clean. Hand SA-key/secret findings to `secrets-sentinel` and plan-level replace hazards to `iac-reviewer`/`verify-plan-safety`.
