---
description: Author Yandex Cloud Terraform — VPC, Managed K8s (regional HA), Managed PostgreSQL/Kafka, Lockbox, KMS, Container Registry, least-privilege IAM — secure and HA by default. Never applies.
argument-hint: <resource-or-stack> [--env=<env>] [--folder=<folder-id>]
---

Invoke the `yc-provisioner` agent to write Yandex Cloud Terraform for `$ARGUMENTS`.

- **resource/stack** — the first positional argument: `network`, `managed-k8s`, `postgres`, `kafka`, `lockbox`, `registry`, or a full stack.
- **env** — target environment (prod gets regional masters, HA data, backups; dev may be zonal/single-host).
- **folder** — `--folder=` to be explicit about the target YC folder (the agent confirms it before writing — never provisions into the wrong folder).

The agent runs `discover-yc-context`, resolves current provider arguments deliberately (registry/MCP/docs), and writes resources that are secure and HA by default: per-zone subnets with default-deny security groups, a regional Managed K8s master with autoscaling node groups, HA managed databases with backups and `prevent_destroy`, Lockbox + KMS, least-privilege IAM service accounts (no admin/editor, keyless preferred), and an encrypted Object Storage state backend.

It self-checks with `verify-yc-resources`, produces a plan for review, and never runs `apply`. Generic Terraform shape is delegated to `terraform-author`. Follow with `/yc-audit` and `/tf-plan-review`.
