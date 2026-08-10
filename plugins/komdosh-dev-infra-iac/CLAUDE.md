# CLAUDE.md — komdosh-dev-infra-iac

Terraform/OpenTofu authoring and review on top of `komdosh-dev-infra-core`, with the Yandex Cloud resource layer built in. One domain: provision infrastructure as code, safely and reviewably, and never apply an unread plan.

## What it adds

| Piece | Purpose |
|---|---|
| [`/tf-module <name>`](commands/tf-module.md) | Author/refactor a module via `iac-author`. `--cloud=`, `--path=` optional. |
| [`/tf-plan-review`](commands/tf-plan-review.md) | Classify a plan (SAFE/REVIEW/DANGEROUS) and review the change via `iac-reviewer`. |
| [`/tf-audit`](commands/tf-audit.md) | Whole-codebase hygiene audit (state, pinning, secrets, `prevent_destroy`, blast radius). |
| [`/yc-provision <resource>`](commands/yc-provision.md) | Author Yandex Cloud Terraform — VPC, Managed K8s, Managed PG/Kafka, Lockbox, KMS, IAM. |
| [`/yc-audit`](commands/yc-audit.md) | YC security/reliability/residency audit — IAM, keys, exposure, HA, backups, 152-FZ. |
| [`/yc-context`](commands/yc-context.md) | Print the resolved cloud/folder/zone, services, network, auth model, state backend. |
| [`iac-author`](agents/iac-author.md) | Writes pinned, conventional Terraform — plus the YC layer when the provider is `yandex`. Never applies. |
| [`iac-reviewer`](agents/iac-reviewer.md) | Read-only review of code + plan across correctness, state safety, security, cost, drift — plus the YC audit families. |
| [`discover-terraform-layout`](skills/discover-terraform-layout/SKILL.md) | Maps roots, backends, providers, env layout, remote-state coupling → descriptor. |
| [`verify-plan-safety`](skills/verify-plan-safety/SKILL.md) | Classifies every plan action; flags `forces replacement` on stateful resources before apply. |
| [`discover-yc-context`](skills/discover-yc-context/SKILL.md) | Resolves cloud/folder/zone, declared managed services, network, auth model, state backend. |
| [`verify-yc-resources`](skills/verify-yc-resources/SKILL.md) | Fast YC preflight — IAM, SA keys, Lockbox, exposure, HA/backups, PII residency. |
| `rules/*.md` | Seven convention documents, imported via `@rules/...` below. |

## Big picture

`iac-author` writes; `iac-reviewer` critiques — they never overlap. Both run `discover-terraform-layout` first so work fits the existing repo, and pick up the YC layer (`discover-yc-context`, the `yc-*` rules) when the `yandex` provider is present. Yandex Cloud is a **provider specialization, not a separate discipline**: the same two agents, the same plan contract, with YC-specific resource semantics and audit families layered on. That keeps the "who writes / who reviews" boundary intact instead of splitting it four ways.

The reviewer anchors on `verify-plan-safety` because **the plan, not the source, is where destroys and replaces hide** — a source diff that looks additive can produce a `-/+` that destroys a database. Neither agent ever runs `apply`, `destroy`, or state-mutating commands; those are human decisions the agents enable by producing a reviewed plan. The Terraform registry MCP (when configured) supplies current provider/module versions so pins are deliberate, not guessed.

Cluster **provisioning** lives here; anything that runs *inside* a cluster (Deployments, ArgoCD Applications) belongs to `komdosh-dev-infra-k8s`.

## The apply contract (from infra-core)

Render (`plan`) → review the blast radius → apply only the exact reviewed artifact. This plugin owns the first two steps for Terraform and hands the third to a human. `prevent_destroy` on stateful resources turns an accidental destroy into a plan error instead of data loss.

## Conventions imported as rules

- **`terraform-style.md`** — module structure, mandatory version pinning (`~>` providers, `?ref=` modules, committed lockfile), typed/described/validated variables with no secret defaults, `for_each` over `count` keyed by a stable id, consistent tagging via a merged local, `fmt`+`validate` before commit.
- **`terraform-state-safety.md`** — remote+locked+encrypted backend always; one state per lifecycle+env, not one monolith; state holds secrets in cleartext (`sensitive` only redacts console); never hand-edit state; `state rm`/`mv`/`import` are human-gated; `-target` is a smell; `prevent_destroy` on data-holding resources.
- **`terraform-plan-review.md`** — the five change verbs, `forces replacement` as the line that hides outages, the plan review checklist (destroy count, reindex churn, provider bump, sensitive diffs, scope), saved plans, and the SAFE/REVIEW/DANGEROUS verdicts.
- **`yc-terraform.md`** — the `yandex` provider shape, folder/cloud scoping, Object Storage state backend, and YC naming/labelling conventions.
- **`yc-security.md`** — least-privilege service accounts (never admin/editor/wildcard), keyless over static keys, Lockbox for secrets, KMS for encryption at rest, default-deny security groups, no public IPs on data resources.
- **`yc-managed-services.md`** — regional vs zonal K8s masters, HA topology and backups for Managed PostgreSQL/Kafka/Redis, `prevent_destroy` on data clusters, private access and TLS.
- **`yc-data-residency.md`** — 152-FZ localization of Russian personal data to `ru-central1`, encryption and access requirements for PII stores, and the 152-FZ-vs-GDPR divergence (localization vs cross-border transfer) that gets flagged for legal review rather than decided here.

## When editing this plugin

- New agent → `agents/<name>.md` (frontmatter `name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + `allowed-tools` for internal read-only skills).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root after edits.

@rules/terraform-style.md
@rules/terraform-state-safety.md
@rules/terraform-plan-review.md
@rules/yc-terraform.md
@rules/yc-security.md
@rules/yc-managed-services.md
@rules/yc-data-residency.md
