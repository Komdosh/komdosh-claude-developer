---
name: verify-plan-safety
user-invocable: false
allowed-tools: Read, Grep, Bash(terraform show:*), Bash(terraform plan:*), Bash(tofu show:*), Bash(jq:*)
description: Classify a Terraform/OpenTofu plan into a SAFE / REVIEW / DANGEROUS verdict before any apply — enumerate every create/update/replace/destroy, flag `forces replacement` on stateful resources, count destroys, detect for_each/count reindex churn and provider-version jumps, and note sensitive-value changes without printing them. Works from live plan output, a saved plan file, or the plan JSON (`terraform show -json`). Read-only — reads and classifies, never applies. Used by /tf-plan-review and iac-reviewer.
---

# Verify Plan Safety

Turn a Terraform/OpenTofu plan into a blast-radius verdict so a human never applies an unread plan. Read-only: this skill reads and classifies plan output; it never runs `apply` or `destroy`. Follow `rules/terraform-plan-review.md`. Track as a todo when invoked.

## Inputs (in order of preference)

1. **Plan JSON** — `terraform show -json tfplan` (most reliable; machine-readable `resource_changes[].change.actions`).
2. **Saved plan** — `terraform show tfplan` (human-readable).
3. **Live plan** — run `terraform plan` read-only if the user permits and state is reachable; otherwise ask the user to paste plan output. Never fabricate a plan.

## Step 1: Tally the change verbs

From `resource_changes[].change.actions` (JSON) or the `+`/`~`/`-/+`/`-` symbols (text):

- `["create"]` → create (`+`)
- `["update"]` → update in place (`~`)
- `["delete","create"]` or `["create","delete"]` → **replace** (`-/+`)
- `["delete"]` → **destroy** (`-`)

Record counts and confirm against the `Plan: X to add, Y to change, Z to destroy` summary.

## Step 2: Flag forces-replacement on stateful resources

- Find every `forces replacement` / `must be replaced` (text) or `replace` action with a `replace_paths` reason (JSON).
- For each, classify the resource type as **stateful** (DB cluster, disk, volume, bucket, managed-service data store) or **stateless** (compute instance behind an LB, SG, DNS record).
- A forced replacement of a **stateful** resource is a DANGEROUS finding: data loss unless backed up. Note whether a `prevent_destroy` lifecycle exists (its absence is a secondary finding).

## Step 3: Detect reindex churn

- Many replaces of the same resource type in one plan usually means a `for_each`/`count` key changed (a list reordered, a map key renamed). This is a mass-replace disguised as a small source diff. Call it out with the count.

## Step 4: Provider and scope checks

- **Provider version jump** — if the plan or lockfile shows a provider major bump, warn: schema changes can force replacements estate-wide.
- **Scope** — does the set of changed resources match the stated intent of the change? Resources in the plan that the change didn't mean to touch indicate drift or a shared-state collision.

## Step 5: Sensitive values

- Note `(sensitive value)` / `sensitive: true` changes: a secret changed. Confirm the source is a secret store, not a new literal. **Never resolve or print the value.**

## Output

```
PLAN SAFETY — <plan source>

Verdict: SAFE | REVIEW | DANGEROUS
Summary: +<a> add · ~<c> change · -/+<r> replace · -<d> destroy

DANGEROUS
- <resource.addr>  REPLACE (forces replacement: <attr>)  — stateful, data loss unless backed up; prevent_destroy: absent
REVIEW
- <resource.addr>  UPDATE  — <disruptive attribute / provider bump / reindex of N>
SAFE
- <n> pure creates, <n> in-place updates, no stateful replace/destroy

Notes: <sensitive changes (no values) · scope observations>
```

- **SAFE** — only creates/in-place updates, no stateful replace/destroy, scope matches intent.
- **REVIEW** — disruptive updates, provider bump, or reindex churn; a human reads before applying.
- **DANGEROUS** — any stateful replace/destroy or scope beyond intent; blocked until backup + sign-off.
