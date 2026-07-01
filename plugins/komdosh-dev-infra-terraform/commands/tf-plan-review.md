---
description: Classify a Terraform/OpenTofu plan (SAFE/REVIEW/DANGEROUS) and review the change for state safety, security, cost, and drift before apply. Read-only.
argument-hint: [plan-file|base-branch] [--json=<plan.json>]
---

Review the pending Terraform/OpenTofu change with the `terraform-reviewer` agent, anchored on the plan.

- If a saved plan or plan JSON is available (`--json=`, a `tfplan` path, or provided output), the agent runs `verify-plan-safety` on it directly.
- Otherwise it reviews the diff against the base branch and asks for a plan (or read-only permission to run `terraform plan`) — the plan is where silent replaces and destroys hide.

Output: a verdict (BLOCKED / CHANGES REQUESTED / CLEAN), the plan classification with add/change/replace/destroy counts, every `forces replacement` on a stateful resource, a one-sentence rollback, and severity-ordered findings with file:line. Never applies; hands the reviewed plan to a human.
