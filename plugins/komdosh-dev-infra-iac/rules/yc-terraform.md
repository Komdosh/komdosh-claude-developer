# Yandex Cloud with Terraform

The `yandex-cloud/yandex` provider layer on top of `rules/terraform-style.md` and `rules/terraform-state-safety.md` — everything there still applies. **Resolve current provider and resource details from the registry or YC docs, not from memory**; the provider evolves.

## Provider and auth

**`cloud_id` and `folder_id` are variables, never literals** — they differ per environment and they identify the blast radius.

Auth precedence: **instance metadata / bound service account (keyless) → a short-lived IAM token in CI → `service_account_key_file` as a last resort**, with the key file living only in a secret store.

Zones are `ru-central1-a|b|d`. **Spread stateful and HA resources across zones**; don't pin everything to one.

## State in Object Storage

The `s3` backend against `storage.yandexcloud.net`, with the `skip_*` validation flags Object Storage needs — including `skip_s3_checksum` on Terraform 1.6.1+. **Confirm the key names against your Terraform version**: recent releases moved `endpoint` to `endpoints.s3`, and a stale example fails obscurely.

The bucket's access keys are a static credential — CI secrets or Lockbox, **never the backend block or git**. Encrypt the bucket; state holds secrets in cleartext.

## Network shape

One `yandex_vpc_network` per environment, and **a subnet per zone** — a subnet is zonal — with non-overlapping CIDRs. Explicit default-deny security groups (`rules/yc-security.md`) attached to instances, clusters, and managed services. Egress for private subnets through a NAT gateway and route table; **private resources get no public IP by default.**

## Naming and structure

Names describe the thing (`yandex_mdb_postgresql_cluster.orders`). A consistent `labels` map — `environment`, `managed-by`, `team`, `service` — because **YC surfaces labels in billing and the console**, so they're how cost gets attributed.

**Split roots by lifecycle and blast radius**: `network` / `data` / `k8s` / `app`, each with its own state. One root for a whole folder is a blast-radius problem.
