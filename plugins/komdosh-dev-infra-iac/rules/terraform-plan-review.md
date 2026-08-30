# Reading a Terraform Plan

Source review tells you intent; **the plan tells you what will happen to real resources.** Never apply a plan you haven't read for blast radius.

## The five verbs

`+` create (low) · `~` update in place (read *which* attribute and whether it's disruptive) · **`-/+` replace** — destroy then create, **the existing resource and its data are gone** · `+/-` replace with better ordering, still a replace · **`-` destroy**.

Read the `Plan: X to add, Y to change, Z to destroy` line first. **Any non-zero destroy on a stateful resource is a stop-and-think.**

## `forces replacement` — the line that hides outages

When an attribute can't change in place, the plan says `# forces replacement`. On a stateful resource that means destroying the data-holding thing and creating a new empty one — from what looks like a one-line attribute diff.

**Grep every plan for `forces replacement` and `must be replaced`.** For each: is the resource stateful, is it backed up, was the replacement intended? A `prevent_destroy` should have caught it; if it didn't, that gap is itself a finding.

## Checklist

1. **Destroy/replace count** — zero on stateful resources unless intended, backed up, and signed off.
2. **Every `forces replacement`**, classified stateful vs stateless.
3. **`for_each`/`count` churn** — a key or list-order change is a **mass replace hiding as a small diff**.
4. **Provider major bump** — schema changes can force replacements estate-wide; read the changelog first.
5. **Sensitive diffs** — a `(sensitive value)` marker means a secret changed. Confirm the source is a store, not a new literal, and **never print the resolved value**.
6. **Scope** — unexpected resources in the plan mean drift, a shared-state collision, or an unintended dependency.
7. **Count sanity** — `3 to add` when you changed one resource means a module or `for_each` expansion you didn't expect.

## Apply the saved plan

`plan -out=tfplan` → `show tfplan` → `apply tfplan`. **Re-running `apply` without a saved plan re-plans against reality that may have moved — you can apply something you never saw.** This plugin reviews the plan and hands the artifact to a human; it never applies.

## Verdicts

**SAFE** — only creates and in-place updates, no `forces replacement`, scope matches intent.
**REVIEW** — disruptive updates, a provider bump, or `for_each` churn.
**DANGEROUS** — any destroy or replace of a stateful resource, a mass reindex, or a scope exceeding the change's intent. Blocked until backed up and signed off.
