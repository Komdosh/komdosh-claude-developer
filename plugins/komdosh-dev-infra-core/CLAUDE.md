# CLAUDE.md — komdosh-dev-infra-core

This file guides Claude Code when `komdosh-dev-infra-core` is active. It loads automatically when the plugin is installed.

## What this plugin is

`komdosh-dev-infra-core` is the **must-have foundation** for infrastructure-as-code and GitOps work. It packages the cross-cutting agents, commands, skills, rules, and one hook that every infra task needs, independent of which tool or cloud you use. The specialist plugins add depth on top of it:

| Plugin | Adds |
|---|---|
| `komdosh-dev-infra-terraform` | Terraform/OpenTofu authoring, plan-safety analysis, state discipline |
| `komdosh-dev-infra-kubernetes` | Hardened manifests (Pod Security Standards restricted), resource discipline, workload troubleshooting |
| `komdosh-dev-infra-argocd` | ArgoCD Application/ApplicationSet authoring, sync/health diagnosis, GitOps delivery |
| `komdosh-dev-infra-yandex` | Yandex Cloud provisioning (Managed K8s, Managed PG/Kafka, Lockbox, IAM), YC security/reliability audit |

This is a **behavioural** plugin — no application code, no build, no test suite. "Editing" it means changing its Markdown/JSON content. It composes with, but does not depend on, the Kotlin/Spring suite (`komdosh-dev-spring-core`'s `infra-expert` writes a service's own Dockerfile/manifests; this suite owns the estate they deploy into).

## Plugin layout

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest |
| [`agents/infra-reviewer.md`](agents/infra-reviewer.md) | Read-only six-dimension review of an infra change (correctness · blast radius · reversibility · security · drift · cost) |
| [`agents/secrets-sentinel.md`](agents/secrets-sentinel.md) | Read-only secrets-leak auditor across every layer; reports by location + type, never the value |
| [`agents/data-protection-auditor.md`](agents/data-protection-auditor.md) | Read-only PII/data-protection auditor across the data lifecycle (encryption, access, residency, retention, erasure); 152-FZ + GDPR; never prints the personal data |
| [`commands/infra-review.md`](commands/infra-review.md) · [`commands/infra-map.md`](commands/infra-map.md) · [`commands/secrets-audit.md`](commands/secrets-audit.md) · [`commands/pii-audit.md`](commands/pii-audit.md) | `/infra-review`, `/infra-map`, `/secrets-audit`, `/pii-audit` |
| [`skills/discover-infra-context/SKILL.md`](skills/discover-infra-context/SKILL.md) | Repo-mapper: tools, clouds, environments, state, secrets → descriptor. Run once per session |
| [`skills/infra-safety-scan/SKILL.md`](skills/infra-safety-scan/SKILL.md) | Seconds-long grep preflight for the highest-signal violations |
| [`skills/pii-exposure-scan/SKILL.md`](skills/pii-exposure-scan/SKILL.md) | Grep preflight for personal-data exposure (unencrypted/public PII stores, PII in logs/events, residency); never prints the data |
| `rules/*.md` | Six convention documents, imported via `@rules/...` below |
| [`hooks/hooks.json`](hooks/hooks.json) · [`hooks/infra-context.sh`](hooks/infra-context.sh) | SessionStart hook: detects an infra repo and injects the plan→review→apply contract once |
| `settings.recommended.json` | Read-only infra commands allowed; every mutating command (`apply`/`destroy`/`sync`/`delete`) denied |

## Big picture: how the pieces collaborate

Every infra action obeys one contract (`rules/iac-safety.md`): **render the desired state → review the blast radius → apply only the reviewed artifact.** The plugin operationalises it:

- `discover-infra-context` orients first — which tools, clouds, and environments exist — so nothing acts blind. Run **once per session**.
- `infra-safety-scan` is the cheap gate: a grep sweep for plaintext secrets, mutable tags, world-open CIDRs, missing limits, local state, and destroy/replace hazards. Run before declaring any infra change done.
- `infra-reviewer` is the deep read-only review of a *change*; `secrets-sentinel` is the exhaustive read-only sweep for *secrets*; `data-protection-auditor` is the read-only sweep for *personal data* across the data lifecycle (encryption, access, residency, retention, erasure — 152-FZ + GDPR). All three delegate depth to the specialist plugins rather than overreaching — the reviewer routes a Terraform state hazard to `terraform-reviewer`, a PSS violation to `k8s-hardening-auditor`, a sync failure to `argocd-diagnostician`, a managed-service blast radius to `yc-auditor`; the data-protection auditor routes residency specifics to `yc-auditor`, secret leaks to `secrets-sentinel`, and app-layer PII-in-code to the Spring suite's `/pii-leakage-check`.

Read-only agents are read-only at the tool layer (`disallowedTools: Edit, Write, MultiEdit, NotebookEdit`) — they report; the specialist author agents change. The recommended permission set keeps every mutating infra command behind an explicit human decision.

## Conventions imported as rules

The five `rules/*.md` files below are loaded via `@rules/...` and apply to any infrastructure you generate or review. Read each in full when its concern is in scope; the essence:

- **`iac-safety.md`** — 12 forbidden patterns and the plan→review→apply contract. Plaintext secrets, mutable tags, `-auto-approve` on an unseen plan, `kubectl apply` against GitOps, `0.0.0.0/0` on admin ports, missing limits, local state, index-keyed `for_each`, unguarded destroy of stateful resources, click-ops, monolithic blast radius, unpinned versions. Reversibility first: know the one-sentence rollback before you change anything.
- **`secrets-hygiene.md`** — a secret never lands in git readable. Where secrets are allowed to live per layer (External Secrets / Sealed Secrets / SOPS / Vault / cloud Lockbox/KMS); base64 ≠ encryption; `sensitive` hides console output not state; a secret in a plan/diff is a leak; rotate-on-exposure over delete.
- **`gitops-principles.md`** — declarative, versioned, pulled, continuously reconciled. No out-of-band changes; no moving targets (mutable branch/tag) in prod; source-of-truth vs promotion mechanics kept separate; rollback = git revert; drift is a signal to investigate.
- **`environment-promotion.md`** — promote the same artifact, change only configuration. No rebuild between environments; per-env deltas via overlays/tfvars/generators; promotion is a reviewable diff; gates increase with blast radius; prod-only constructs are a smell.
- **`infra-review.md`** — the six review dimensions, BLOCKER/WARNING/INFO severity, cite file:line + concrete impact, re-scan before a clean verdict, report only what's grounded in the diff.
- **`pii-data-protection.md`** — the canonical personal-data rule at the infrastructure layer. Classify before you protect (direct/quasi/sensitive/financial); encrypt at rest (KMS) + in transit; least-privilege access; network isolation; PII leaks through the back doors (logs, backups, event streams, object storage, non-prod copies); retention + erasure-reaches-every-copy (crypto-shred backups); and the two regimes — 152-FZ localization (RU data in `ru-central1`) vs GDPR cross-border-transfer restriction, whose divergence usually forces jurisdiction-partitioned data stores. Engineering obligations, not legal advice.

## When editing this plugin

- New agent: `agents/<name>.md` with frontmatter `name`, `model` (alias — `haiku|sonnet|opus|inherit`), and a `description` with concrete trigger phrases. Read-only agents declare `disallowedTools`.
- New skill: `skills/<name>/SKILL.md` with frontmatter `name` + `description` (+ `user-invocable: false` for internal skills, `allowed-tools` for read-only scans) and a numbered checklist tracked as todos when invoked.
- New command: `commands/<verb-noun>.md`.
- New rule: add the `rules/<file>.md` **and** the matching `@rules/<file>.md` import line below, or it won't load.
- Nothing to build or test — verification is "does the prose still describe the agent's actual behavior and current rule references." Run `tools/lint-marketplace.sh` from the repo root.

@rules/iac-safety.md
@rules/secrets-hygiene.md
@rules/gitops-principles.md
@rules/environment-promotion.md
@rules/infra-review.md
@rules/pii-data-protection.md
