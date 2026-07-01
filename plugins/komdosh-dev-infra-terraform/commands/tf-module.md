---
description: Author or refactor a Terraform/OpenTofu module — pinned providers, typed variables, stable-key for_each, prevent_destroy on stateful resources, remote encrypted state. Never applies.
argument-hint: <module-name-or-resource> [--cloud=<yandex|aws|gcp>] [--path=<dir>]
---

Invoke the `terraform-author` agent to write or refactor Terraform/OpenTofu for `$ARGUMENTS`.

- **name/resource** — the first positional argument: a module name (`network`, `postgres`) or a resource to add.
- **cloud** — from `--cloud=`; when `yandex` and the `komdosh-dev-infra-yandex` plugin is installed, the author delegates managed-service/IAM/network specifics to `yc-provisioner`.
- **path** — target directory, if not the current module.

The agent runs `discover-terraform-layout` first to match the repo's structure, pins provider/module versions deliberately (Terraform registry MCP when available), keeps secrets out of code and state, guards stateful resources with `prevent_destroy`, and runs `fmt`/`validate`. It produces a reviewable plan for a human — it never runs `apply` or `destroy`. Follow with `/tf-plan-review` before applying.
