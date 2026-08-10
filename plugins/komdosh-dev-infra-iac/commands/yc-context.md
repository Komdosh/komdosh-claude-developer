---
description: Resolve and print the Yandex Cloud context for this repo — cloud/folder/zone, declared managed services, network layout, auth model, and state backend — with any hygiene gaps. Read-only.
argument-hint: [--path=<dir>]
---

Run the `discover-yc-context` skill and present its descriptor as a readable summary.

Report:
- **Context** — resolved `cloud_id` / `folder_id` / default zone (from `yc config list` and the Terraform provider), and any mismatch between the CLI folder and the Terraform folder (you may be pointed at the wrong environment).
- **Services** — which YC managed services are declared (Managed K8s, PostgreSQL, Kafka, Redis, Lockbox, KMS, Container Registry, Object Storage) and in which environments.
- **Network** — VPC/subnet-per-zone/security-group layout.
- **Auth** — keyless (bound SA / metadata) vs `service_account_key_file`; any SA keys or static keys in the tree (routed to `secrets-sentinel`).
- **State** — Object Storage backend + encryption, or a local-state finding.
- **Gaps** — hardcoded folder IDs, plaintext SA keys, missing KMS, zonal prod masters, and similar, plus the single highest-value next action.

Read-only. Use it to get oriented before `/yc-provision` or `/yc-audit`.
