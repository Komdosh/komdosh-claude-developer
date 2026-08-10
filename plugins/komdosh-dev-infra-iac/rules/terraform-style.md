# Terraform / OpenTofu Style

Conventions for readable, reviewable, reproducible Terraform. Applies equally to OpenTofu (`tofu`) — the language is the same; where they diverge it's called out.

## Module structure

A module is a directory of `.tf` files with a single, named responsibility. Standard file split:

```
modules/<name>/
├── main.tf         resources + locals
├── variables.tf    input variables (with type, description, and validation)
├── outputs.tf      outputs (with description)
├── versions.tf     required_version + required_providers (pinned)
└── README.md       what it provisions, inputs, outputs, example
```

- One module = one concern (a network, a database, a cluster). A module that provisions "everything" is a blast-radius problem, not a convenience.
- Root modules (the ones you `apply`) are thin: they wire child modules and pass env-specific values. Logic lives in reusable child modules.

## Version pinning is mandatory

Nothing floats. Unpinned versions turn an unrelated PR into a surprise upgrade.

```hcl
terraform {
  required_version = "~> 1.9"          # or the tofu equivalent
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.129"             # pin the provider
    }
  }
}
```

- Pin **provider** versions with `~>` (allow patch/minor, block major).
- Pin **module** sources by ref: `source = "git::https://…//modules/net?ref=v1.4.0"` — never a moving branch.
- Commit `.terraform.lock.hcl` so everyone resolves the same provider builds.
- Query the current version deliberately (Terraform registry MCP `get_latest_provider_version` / `get_latest_module_version`, or the registry) before bumping — don't guess.

## Variables and outputs

- Every variable declares `type`, `description`, and — where a constraint exists — `validation`. No untyped `variable "x" {}`.
- No `default` on a variable that names an environment-specific or secret value; force the caller to be explicit. Secrets get no default at all (see `rules/secrets-hygiene.md` in infra-core).
- Every output has a `description`. Mark secret outputs `sensitive = true` (and remember that only hides console output, not state).

## `for_each` over `count`

Prefer `for_each` keyed by a **stable identifier**. `count` (and `for_each` over a list index) reindexes on insertion/removal and destroys+recreates unrelated resources.

```hcl
# GOOD — keyed by a stable name; adding "cache" never touches "db"
resource "yandex_compute_instance" "node" {
  for_each = toset(["db", "app", "cache"])
  name     = each.key
}

# RISKY — removing element 0 shifts every index → mass replace
resource "yandex_compute_instance" "node" {
  count = length(var.nodes)
  name  = var.nodes[count.index]
}
```

## Naming, tagging, locals

- Resource **names** describe the thing, not its type: `resource "yandex_vpc_network" "main"`, not `"network_1"`.
- Apply a consistent label/tag set to every taggable resource (`environment`, `managed-by = "terraform"`, `team`, `service`) via a `local` merged in — so ownership and cost attribution are always present.
- Use `locals` for values computed or repeated more than once; don't repeat an expression across resources.

## Formatting and hygiene

- `terraform fmt` (or `tofu fmt`) is not optional — code is canonically formatted before commit.
- `terraform validate` passes before any plan.
- No provisioners (`local-exec`/`remote-exec`) except as a documented last resort — they break the declarative model and aren't tracked in state.
- Keep provider configuration (region, auth, folder/project) parameterised, never hardcoded in a module.
