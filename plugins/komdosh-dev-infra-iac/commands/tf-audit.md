---
description: Whole-codebase Terraform/OpenTofu audit — state safety, provider/module pinning, secrets, prevent_destroy coverage, blast-radius layout — classified BLOCKER/WARNING/INFO. Read-only.
argument-hint: [--path=<dir>]
---

Run a repository-wide Terraform/OpenTofu hygiene audit with the `iac-reviewer` agent (audit mode, not a single-change review).

The agent runs `discover-terraform-layout` to map roots, backends, providers, and env layout, then reports every hygiene gap:

- **State** — local state, missing locking/encryption, monolithic state spanning prod + non-prod.
- **Pinning** — unpinned providers/modules, missing `required_version`, uncommitted `.terraform.lock.hcl`, floating module `ref`.
- **Secrets** — literals in code/tfvars, defaulted secret variables (routes deep findings to `secrets-sentinel`).
- **Reversibility** — stateful resources without `prevent_destroy`.
- **Blast radius** — modules that provision "everything," `count`/index-keyed `for_each` reindex hazards.

Output is a BLOCKER/WARNING/INFO report with file:line and concrete impact, plus the single highest-value remediation. Read-only — never applies, never edits.
