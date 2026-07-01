# CLAUDE.md — komdosh-dev-infra-terraform

Terraform/OpenTofu authoring and review on top of `komdosh-dev-infra-core`. One domain: provision infrastructure as code, safely and reviewably, and never apply an unread plan.

## What it adds

| Piece | Purpose |
|---|---|
| [`/tf-module <name>`](commands/tf-module.md) | Author/refactor a module via `terraform-author`. `--cloud=`, `--path=` optional. |
| [`/tf-plan-review`](commands/tf-plan-review.md) | Classify a plan (SAFE/REVIEW/DANGEROUS) and review the change via `terraform-reviewer`. |
| [`/tf-audit`](commands/tf-audit.md) | Whole-codebase hygiene audit (state, pinning, secrets, `prevent_destroy`, blast radius). |
| [`terraform-author`](agents/terraform-author.md) | Writes pinned, conventional Terraform; keys `for_each` by stable id; guards stateful resources; never applies. |
| [`terraform-reviewer`](agents/terraform-reviewer.md) | Read-only review of code + plan across correctness, state safety, security, cost, drift. |
| [`discover-terraform-layout`](skills/discover-terraform-layout/SKILL.md) | Maps roots, backends, providers, env layout, remote-state coupling → descriptor. |
| [`verify-plan-safety`](skills/verify-plan-safety/SKILL.md) | Classifies every plan action; flags `forces replacement` on stateful resources before apply. |
| `rules/*.md` | Three convention documents, imported via `@rules/...` below. |

## Big picture

`terraform-author` writes; `terraform-reviewer` critiques — they never overlap. Both run `discover-terraform-layout` first so work fits the existing repo. The reviewer anchors on `verify-plan-safety` because **the plan, not the source, is where destroys and replaces hide** — a source diff that looks additive can produce a `-/+` that destroys a database. Neither agent ever runs `apply`, `destroy`, or state-mutating commands; those are human decisions the agents enable by producing a reviewed plan.

When the target is Yandex Cloud and `komdosh-dev-infra-yandex` is installed, `terraform-author` delegates managed-service/IAM/network specifics to `yc-provisioner` and keeps the generic Terraform shape. The Terraform registry MCP (when configured) supplies current provider/module versions so pins are deliberate, not guessed.

## The apply contract (from infra-core)

Render (`plan`) → review the blast radius → apply only the exact reviewed artifact. This plugin owns the first two steps for Terraform and hands the third to a human. `prevent_destroy` on stateful resources turns an accidental destroy into a plan error instead of data loss.

## Conventions imported as rules

- **`terraform-style.md`** — module structure, mandatory version pinning (`~>` providers, `?ref=` modules, committed lockfile), typed/described/validated variables with no secret defaults, `for_each` over `count` keyed by a stable id, consistent tagging via a merged local, `fmt`+`validate` before commit.
- **`terraform-state-safety.md`** — remote+locked+encrypted backend always; one state per lifecycle+env, not one monolith; state holds secrets in cleartext (`sensitive` only redacts console); never hand-edit state; `state rm`/`mv`/`import` are human-gated; `-target` is a smell; `prevent_destroy` on data-holding resources.
- **`terraform-plan-review.md`** — the five change verbs, `forces replacement` as the line that hides outages, the plan review checklist (destroy count, reindex churn, provider bump, sensitive diffs, scope), saved plans, and the SAFE/REVIEW/DANGEROUS verdicts.

## When editing this plugin

- New agent → `agents/<name>.md` (frontmatter `name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + `allowed-tools` for internal read-only skills).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root after edits.

@rules/terraform-style.md
@rules/terraform-state-safety.md
@rules/terraform-plan-review.md
