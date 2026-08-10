# Terraform State Safety

State is the most dangerous file in a Terraform project: it maps code to real resources, it contains secrets in cleartext, and corrupting it can orphan or destroy infrastructure. Treat it accordingly.

## Remote, locked, encrypted — always

Local `terraform.tfstate` in a shared repo is a defect. Two people applying at once corrupt it; it lives on one laptop; it ends up in git with secrets in it.

```hcl
# Example: S3-compatible backend (works for AWS S3 and Yandex Object Storage)
terraform {
  backend "s3" {
    bucket   = "acme-tfstate"
    key      = "prod/network/terraform.tfstate"
    region   = "ru-central1"
    encrypt  = true                 # encrypt state at rest
    # locking: DynamoDB (AWS) or the backend's native lock; never skip locking on a shared state
  }
}
```

Requirements for any team state:
- **Remote backend** (S3 / Object Storage / GCS / Terraform Cloud) — never local for shared infra.
- **Locking** enabled, so concurrent applies can't race.
- **Encryption at rest** on the state bucket, plus restricted access (state contains secrets in cleartext).
- **One state per lifecycle + environment**: `prod/network`, `prod/data`, `staging/app`, … Not one giant state for the whole estate — a single state is a single blast radius and a slow, risky plan.

## Secrets live in state — plan for it

Terraform writes resource attributes, including passwords and keys, to state in cleartext. `sensitive = true` only redacts CLI output.

- Encrypt the backend; lock down who can read the state bucket.
- Prefer reading secrets at apply time from a secret store (Vault / Lockbox / KMS data source) so fewer secrets persist in state.
- Never commit a state file; never paste state contents into chat/PRs/logs.

## Never edit or surgically mutate state by hand

State operations are where irreversible mistakes happen. Treat these as dangerous, human-gated actions — this plugin's agents never run them:

- `terraform state rm` / `state mv` — silently detaches or renames tracked resources; a wrong key orphans or clobbers real infrastructure.
- `terraform import` — bring a pre-existing resource under management deliberately, with the config written first; verify with a plan that shows **no changes** afterward.
- Direct edits to the state JSON — never.

## `-target` is a smell, not a tool

`terraform apply -target=…` applies a partial graph, leaving state and reality inconsistent with the code. It's an incident-recovery escape hatch, not a workflow. If you reach for `-target` routinely, the state is too big — split it.

## Drift and refresh

- State can diverge from reality (a manual change, an external controller). `terraform plan` shows drift as unexpected diffs.
- Investigate drift's cause before blindly applying it away — a manual prod change reverted by a blind apply can cause an outage.
- Never run a destroy to "clean up" drift without knowing exactly what will be destroyed.

## `prevent_destroy` on stateful resources

Guard databases, disks, buckets, and anything holding data:

```hcl
resource "yandex_mdb_postgresql_cluster" "main" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

This turns an accidental destroy/replace into a plan error instead of data loss. Removing the guard is itself a reviewable, intentional act.
