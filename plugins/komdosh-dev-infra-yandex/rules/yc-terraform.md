# Yandex Cloud with Terraform

Conventions for the `yandex-cloud/yandex` provider. This builds on the terraform plugin's `rules/terraform-style.md` and `rules/terraform-state-safety.md` — everything there (pinning, `for_each`, remote state, `prevent_destroy`) still applies; this file adds the YC-specific shape. Resolve current provider/resource details deliberately (Terraform registry / MCP / `yandex.cloud` docs) rather than from memory — the provider evolves.

## Provider and auth

```hcl
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.129"          # pin; check the registry for current
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id          # never hardcoded
  folder_id = var.folder_id
  zone      = var.default_zone      # e.g. ru-central1-a
  # auth: prefer keyless. On a VM/CI runner with a bound SA, use instance metadata.
  # A service_account_key_file is a long-lived credential — see rules/yc-security.md.
}
```

- **`cloud_id` / `folder_id`** are variables, never literals — they differ per environment and identify blast radius.
- **Auth precedence**: instance metadata / bound service account (keyless) > short-lived IAM token from CI > `service_account_key_file` (last resort, and the key file lives only in a secret store, never in git).
- **Zones**: `ru-central1-a`, `ru-central1-b`, `ru-central1-d`. Spread stateful/HA resources across zones; don't pin everything to one.

## State backend — Object Storage (S3-compatible)

YC state lives in Object Storage via the `s3` backend. Confirm the exact keys against the current provider/Terraform version — recent versions changed `endpoint` → `endpoints.s3` and added checksum-skip flags:

```hcl
terraform {
  backend "s3" {
    endpoints = { s3 = "https://storage.yandexcloud.net" }
    bucket    = "acme-tfstate"
    region    = "ru-central1"
    key       = "prod/network/terraform.tfstate"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true       # Terraform 1.6.1+ against Object Storage
    # encryption + locking: enable bucket encryption and a lock mechanism; never unlocked shared state
  }
}
```

The state bucket's access keys are a static-key credential — store them in CI secrets / Lockbox, never in the backend block or git. Encrypt the bucket (state holds secrets in cleartext).

## Network shape

- One `yandex_vpc_network` per environment; a `yandex_vpc_subnet` **per zone** (a subnet is zonal) with non-overlapping CIDRs.
- `yandex_vpc_security_group` with explicit ingress/egress; default-deny posture (see `rules/yc-security.md`). Attach SGs to instances/clusters/managed services.
- Egress to the internet via a NAT gateway / Cloud NAT + route table for private subnets — private resources shouldn't get public IPs by default.

## Naming, labels, structure

- Resource names describe the thing (`yandex_vpc_network.main`, `yandex_mdb_postgresql_cluster.orders`).
- Apply a consistent `labels` map (`environment`, `managed-by = "terraform"`, `team`, `service`) — YC surfaces labels in billing and console.
- Split roots by lifecycle and blast radius: `network` / `data` (managed services) / `k8s` / `app`, each its own state. A single root for the whole folder is a blast-radius problem.

## Delegation

This plugin owns YC resource specifics. The generic Terraform shape — module layout, variable typing, plan review, `verify-plan-safety` — stays with `terraform-author`/`terraform-reviewer`. `yc-provisioner` writes YC resources following both rule sets; hand a non-YC provider back to `terraform-author`.
