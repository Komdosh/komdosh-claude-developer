---
name: discover-yc-context
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(find:*), Bash(yc config list:*), Bash(yc resource-manager folder list:*)
description: Resolve the Yandex Cloud context for an IaC repo into a structured descriptor — cloud_id/folder_id and default zone (from yc CLI config and/or the Terraform provider block), which YC managed services are declared (Managed K8s, PostgreSQL, Kafka, Redis, Lockbox, KMS, Container Registry, Object Storage), the VPC/subnet/security-group layout, the auth model (keyless vs service-account key), and the Object Storage state backend. Read-only; degrades gracefully when the yc CLI is absent. Run before provisioning or auditing YC resources. Consumed by iac-author and iac-reviewer.
---

# Discover Yandex Cloud Context

Establish which cloud/folder/zone the work targets and which YC services are in play, so provisioning and audit are grounded in the real context. Read-only.

## 1. Resolve cloud / folder / zone

- **From the CLI (best-effort)**: `yc config list` → `cloud-id`, `folder-id`, `compute-default-zone`. Record them. If the CLI is absent or unconfigured, skip — don't fail.
- **From Terraform**: read the `provider "yandex"` block and its variables/tfvars for `cloud_id`, `folder_id`, `zone`. Flag any hardcoded literal (should be a variable — `rules/yc-terraform.md`).
- Reconcile: if the CLI folder and the Terraform folder differ, note it — the session may be pointed at the wrong environment.

## 2. Inventory declared YC resources

Grep the Terraform for `yandex_*` resources and bucket them:

| Category | Resource types |
|---|---|
| Network | `yandex_vpc_network`, `yandex_vpc_subnet`, `yandex_vpc_security_group`, `yandex_vpc_gateway`, route tables |
| Kubernetes | `yandex_kubernetes_cluster`, `yandex_kubernetes_node_group` |
| Data | `yandex_mdb_postgresql_cluster`, `..._mysql_`, `..._kafka_`, `..._redis_`, `..._opensearch_`, `..._clickhouse_` |
| Secrets/crypto | `yandex_lockbox_secret`, `yandex_kms_symmetric_key` |
| Registry/storage | `yandex_container_registry`, `yandex_storage_bucket` |
| IAM | `yandex_iam_service_account`, `..._service_account_key`, `..._static_access_key`, `yandex_resourcemanager_folder_iam_member/binding/policy` |

Record counts and which environments each appears in.

## 3. Auth model

- Is the provider using a bound service account / instance metadata (keyless), a short-lived IAM token, or a `service_account_key_file` (long-lived — a finding to scrutinise)?
- Are there `*-key.json` files in the tree, or SA keys/static keys written to `.tfvars`/outputs? Route to `secrets-sentinel`.

## 4. State backend

- The Object Storage `s3` backend block: bucket, key, encryption, locking. Local state is a finding (`rules/terraform-state-safety.md`).

## 5. Return the descriptor

```json
{
  "cloud_id": "<id or unknown>",
  "folder_id": "<id or unknown>",
  "default_zone": "ru-central1-a",
  "cli_available": true,
  "hardcoded_ids": ["provider folder_id literal at <file>:<line>"],
  "services": { "k8s": true, "postgresql": true, "kafka": false, "lockbox": true, "kms": true, "container_registry": true, "object_storage": true },
  "network": { "networks": 1, "subnets_per_zone": true, "security_groups": 3 },
  "auth_model": "keyless|iam-token|sa-key-file",
  "sa_keys_in_tree": ["<file>:<line>"],
  "state_backend": { "type": "yc-object-storage|local", "encryption": "yes|no|unknown" },
  "gaps": ["hardcoded folder_id", "SA key in tfvars", "no KMS on data bucket", "zonal k8s master in prod"]
}
```

`gaps` seeds `/yc-audit`; `sa_keys_in_tree` routes to `secrets-sentinel`.
