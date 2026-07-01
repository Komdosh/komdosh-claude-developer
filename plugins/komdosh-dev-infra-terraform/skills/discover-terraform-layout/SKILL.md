---
name: discover-terraform-layout
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(terraform version:*), Bash(terraform providers:*), Bash(tofu version:*), Bash(find:*)
description: Map a Terraform/OpenTofu codebase into a structured descriptor — root modules vs reusable child modules, backend configuration (type, locking, encryption), required providers and pinned versions, workspace-vs-directory environment layout, per-env tfvars, and remote-state data-source coupling between root modules. Read-only. Run before authoring or reviewing Terraform so the work respects the existing layout instead of guessing. Consumed by terraform-author and terraform-reviewer.
---

# Discover Terraform Layout

Build the structural picture of a Terraform/OpenTofu codebase so downstream work fits the existing conventions rather than inventing new ones. Read-only. Track as a todo when invoked.

## Step 1: Detect Terraform vs OpenTofu, and the roots

- Glob for `*.tf`, `*.tf.json`, `.terraform.lock.hcl`.
- A **root module** is a directory that declares a `backend` and/or is where `apply` runs (often `envs/*/`, `live/*/`, or the repo root). A **child module** is referenced via `module "…" { source = … }` and never applied directly.
- Record whether the toolchain is Terraform or OpenTofu (`tofu` presence, `.terraform.lock.hcl`, provider registries). They share syntax; note which so commands use the right binary.

## Step 2: Read backend configuration

For each root module, read the `terraform { backend "…" {} }` block:

- **Type**: `s3` (AWS or Yandex Object Storage), `gcs`, `azurerm`, `remote`/`cloud` (Terraform Cloud), or **`local`/none** (a finding — see `rules/terraform-state-safety.md`).
- **Locking**: DynamoDB table (AWS S3), native lock (Object Storage/GCS/TFC), or absent (finding).
- **Encryption**: `encrypt = true` for S3, bucket-level encryption, or unknown.
- One state per lifecycle+env, or one giant state (blast-radius finding).

## Step 3: Providers and version pinning

- Read every `required_providers`: source + version constraint. Flag any provider with no `version` (unpinned — finding).
- Read `required_version`. Flag its absence.
- Note whether `.terraform.lock.hcl` is committed (it should be).
- Identify the cloud(s) the providers target — hand YC-provider specifics to the `komdosh-dev-infra-yandex` plugin when present.

## Step 4: Environment layout

Determine how environments are separated (see `rules/environment-promotion.md` in infra-core):

- **Directory-per-env** — `envs/{dev,staging,prod}/` each a root module with its own state + tfvars (preferred; clearest blast-radius isolation).
- **Workspaces** — one root, `terraform workspace` per env (record; note the shared-backend caveat).
- **tfvars-per-env** — `dev.tfvars`, `prod.tfvars` applied against one root.

Record env names and mechanism. Flag prod sharing a state file with non-prod.

## Step 5: Cross-module coupling

- Find `data "terraform_remote_state"` blocks — these couple root modules (e.g. `app` reads `network`'s outputs). Map the dependency graph; it dictates apply order and blast radius.
- Note `module` sources pinned by `?ref=` vs floating (finding).

## Step 6: Return the descriptor

```json
{
  "toolchain": "terraform|opentofu",
  "root_modules": [{ "path": "…", "backend": "s3|gcs|local|none", "locking": "yes|no|unknown", "encryption": "yes|no|unknown", "state_scope": "lifecycle-split|monolithic" }],
  "child_modules": ["…"],
  "providers": [{ "source": "yandex-cloud/yandex", "version": "~> 0.129", "pinned": true }],
  "required_version": "~> 1.9 | absent",
  "lockfile_committed": true,
  "environments": [{ "name": "prod", "mechanism": "dir|workspace|tfvars" }],
  "remote_state_edges": [{ "from": "app", "to": "network" }],
  "gaps": ["unpinned provider X", "local state in root Y", "no prevent_destroy on DB Z"]
}
```

`gaps` seeds the `/tf-audit` findings and tells `terraform-reviewer` where to look first.
