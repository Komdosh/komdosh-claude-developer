# Reading a Terraform Plan

The plan is where the truth lives. Source review tells you intent; the plan tells you what will actually happen to real resources. **Never apply a plan you haven't read for blast radius.**

## The five change verbs

Every planned action is one of these. Attention scales with danger:

| Symbol | Action | Risk |
|---|---|---|
| `+` | create | low — new resource, nothing existing touched |
| `~` | update in place | low–medium — read what attribute changes and whether it's disruptive |
| `-/+` | **replace** (destroy then create) | **high** — the existing resource is destroyed; data and identity are lost |
| `+/-` | replace (create then destroy) | high — less bad ordering, still a replace |
| `-` | destroy | **high** — resource removed |

The plan summary line — `Plan: X to add, Y to change, Z to destroy` — is the first thing to read. Any non-zero destroy count on a stateful resource is a stop-and-think.

## Forces replacement — the line that hides outages

When an attribute change can't be done in place, the plan prints `# forces replacement`. On a stateful resource this means **destroy the data-holding thing and make a new empty one**.

```
# yandex_mdb_postgresql_cluster.main must be replaced
-/+ resource "yandex_mdb_postgresql_cluster" "main" {
      ~ network_id = "enp1…" -> "enp2…"  # forces replacement
    }
```

Grep every plan for `forces replacement` and `must be replaced`. For each, ask: is this resource stateful? Is the data backed up? Is the replacement intended? A `prevent_destroy` lifecycle should have caught it — if it didn't, that's a gap.

## The review checklist for a plan

1. **Destroy/replace count** — zero on stateful resources unless explicitly intended, backed up, and signed off.
2. **`forces replacement`** — enumerate every one; classify stateful vs stateless.
3. **`for_each`/`count` churn** — a reindex that replaces many resources at once (a key or list-order change) is a mass-replace hiding as a small diff.
4. **Provider version jump** — a major provider bump can change resource schemas and force replacements estate-wide; review the provider changelog first.
5. **Sensitive diffs** — `(sensitive value)` markers mean a secret changed; confirm the source is a store, not a new literal, and never print the resolved value.
6. **Scope** — does the plan touch only what the change intended? Unexpected resources in the plan mean drift, a shared-state collision, or an unintended dependency.
7. **Count sanity** — `Plan: 3 to add` when you changed one resource means a `for_each` or module expansion you didn't expect.

## Saved plans

For anything non-trivial, apply the **exact** reviewed plan, not a re-planned one:

```bash
terraform plan -out=tfplan     # save
terraform show tfplan          # review this artifact
terraform apply tfplan         # apply exactly what was reviewed
```

Re-running `apply` without a saved plan re-plans against possibly-changed reality — you might apply something you never saw. (This plugin never runs `apply`; it reviews the plan and hands the reviewed artifact to a human.)

## Verdicts

- **SAFE** — only `+`/`~`, no `forces replacement`, no destroys, scope matches intent.
- **REVIEW** — updates with disruptive attributes, a provider bump, or `for_each` churn; a human reads it before applying.
- **DANGEROUS** — any destroy/replace of a stateful resource, a mass reindex, or a scope that exceeds the change's intent. Blocked until backed up + signed off.
