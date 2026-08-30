# Terraform / OpenTofu Style

Applies equally to OpenTofu.

## Module structure

`modules/<name>/` with `main.tf` · `variables.tf` · `outputs.tf` · `versions.tf` · `README.md`.

**One module, one concern.** A module that provisions "everything" is a blast-radius problem, not a convenience. Root modules stay thin: they wire child modules and pass environment values; the logic lives in reusable children.

## Pinning is mandatory

Nothing floats — an unpinned version turns an unrelated PR into a surprise upgrade.

Pin `required_version` and every provider with `~>` (patch and minor, never major) · pin module sources by `?ref=v1.4.0`, **never a moving branch** · commit `.terraform.lock.hcl` so everyone resolves identical provider builds.

**Query the registry (or the Terraform MCP) before bumping — never guess a version.**

## Variables and outputs

Every variable declares `type`, `description`, and a `validation` where a constraint exists. **No default on an environment-specific value, and no default at all on a secret** — force the caller to be explicit. Every output has a description; secret outputs are `sensitive`, which hides console output and **not** state.

## `for_each` over `count`

Key by a **stable identifier**. `count`, and `for_each` over a list index, reindexes on insertion or removal — removing one element shifts every index and mass-replaces unrelated resources.

```hcl
for_each = toset(["db", "app", "cache"])   # adding "cache" never touches "db"
```

## Naming and tagging

Names describe the thing, not its type (`"main"`, not `"network_1"`). Every taggable resource carries a consistent set — `environment`, `managed-by`, `team`, `service` — merged in from a `local`, so ownership and cost attribution are always present.

## Hygiene

`fmt` before commit and `validate` before any plan, both non-optional · **no `local-exec`/`remote-exec` provisioners** except as a documented last resort — they break the declarative model and aren't tracked in state · provider configuration is parameterised, never hardcoded in a module.
