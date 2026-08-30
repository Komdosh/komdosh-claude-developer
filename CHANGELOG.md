# Changelog

All notable changes to this marketplace. Format follows [Keep a Changelog](https://keepachangelog.com/); the marketplace `version` in `.claude-plugin/marketplace.json` tracks the wave, individual plugins version independently.

## [0.6.0] — 2026-08-30

Compaction wave. A redundancy review of all 8 plugins — this time of the *prose*, not the plugin graph — cuts the marketplace nearly in half and fixes six real defects, several of them left behind by the 0.5.0 consolidation. No capability removed: the same 30 agents, 53 commands, 39 skills, and 42 rules ship, saying less.

The organising principle, now written into the README as a fourth design rule: **write down what a good model gets wrong, not what it already knows.** A rule earns its place by naming a project-specific decision, a non-obvious trap, a hard prohibition, or a routing boundary. Naming conventions, REST verb semantics, `data class` over `class`, and a code sample of a standard idiom are none of those — they cost context on every session and teach nothing. The corollary applies to structure: a `CLAUDE.md` section that summarises rule files imported in full twenty lines below it is pure duplication, and "when editing this plugin" instructions are paid for in every user session by the ~0% of sessions that edit the plugin.

The always-loaded budget — every `CLAUDE.md` plus every `@rules/*.md` import, paid on every session — drops from **232 KB to 115 KB (−50%)**, roughly 30k tokens reclaimed with the full suite installed. Total plugin content: **834 KB → 440 KB (−47%)**, 11,769 lines deleted against 2,621 added.

| Plugin | Always-loaded |
|---|---|
| `spring-core` | 91 KB → 39 KB (−58%) |
| `spring-quality` | 22 KB → 9 KB (−57%) |
| `spring-delivery` | 22 KB → 13 KB (−41%) |
| `revealer` | 8.1 KB → 3.4 KB (−58%) |
| `kotlin-extras` | 1.4 KB → 0.6 KB (−60%) |
| `infra-core` | 33 KB → 18 KB (−45%) |
| `infra-iac` | 32 KB → 18 KB (−42%) |
| `infra-k8s` | 24 KB → 14 KB (−42%) |

### Fixed

- **36 of 53 commands shipped with no frontmatter**, so they showed no description in the `/` menu — and `lint-marketplace.sh` check 4, whose header claimed to cover "every agent/command/skill", globbed only `agents/*.md` and `skills/*/SKILL.md`. The lint never looked at a command, so the gap survived every commit since commands were introduced. Every command now declares `description` (plus `argument-hint` where it takes arguments); the lint globs `commands/*.md` in both the frontmatter check and the description-budget check, going from 234 to **340 checks**.
- **`recommend-plugin` could never recommend half the marketplace.** Its discovery filtered installed plugins to `komdosh-dev-{spring,kotlin}-*` in three places — the `marketplace.json` fallback search, the `find` pattern, and the name guard — so `infra-core`, `infra-iac`, `infra-k8s`, and `revealer` were structurally invisible to it. Its own worked example then told the user that authoring a Helm chart had "no marketplace capability", which `infra-k8s` has owned since 0.4.0. Discovery now matches the whole `komdosh-dev-*` namespace, and the disambiguation rules route manifests, Helm, ArgoCD, Terraform, cloud resources, and infra PII to the infra plugins explicitly.
- **Three gates keyed off marker files that nothing writes.** `lifecycle-status` gate 13 (code review) looked for `docs/.last-review.json` and gate 15 (service readiness) for `docs/.last-readiness-audit.json`, both described as files the reviewing agent "could write" — but `code-reviewer` carries `disallowedTools: [Edit, Write, …]`, so it structurally cannot write one, and no other agent does. `library-publisher` gated its publish flow on a `docs/release/.last-readiness-*.json` that `/release-prep` never emits. The phantom markers are gone: gates 13 and 15 report **UNKNOWN by design** with the reason stated, and the publish flow requires a `/release-prep` observed passing in-session rather than inferred from disk.
- **`discover-infra-context` emitted dead plugin names.** Its descriptor's `recommended_plugin` field still offered `infra-terraform`, `infra-kubernetes`, `infra-argocd`, and `infra-yandex` — all merged away in 0.5.0 — so a consumer routing on that field was pointed at plugins that no longer exist. Now `komdosh-dev-infra-iac | komdosh-dev-infra-k8s | komdosh-dev-infra-core`.
- **Consolidation leftovers from 0.5.0.** `infra-reviewer` and `data-protection-auditor` listed merged agents twice in their routing tables (`iac-author, k8s-author, k8s-author, iac-author`); `infra-core`'s `CLAUDE.md` named each sibling plugin twice and called six rule files "the five"; `yc-terraform.md` closed with a delegation section handing YC work "back to `iac-author`" from a plugin whose author *is* `iac-author`; and `infra-k8s` deferred to `k8s-diagnostician` "if the kubernetes plugin is installed", though that agent ships in `infra-k8s` itself. All corrected, and the remaining `yandex plugin` / `terraform plugin` prose references now name the plugins that exist.
- **Invalid frontmatter and broken cross-plugin links.** `security-auditor` declared `skills: [… core/pii-safety-scan (depth=audit)]`, which resolves to no skill — the depth argument belonged in the body, not the name. `spring-quality`'s `platform-module.md` linked to `domain-purity.md`, `hexagonal.md`, and `check-adr-required` as if they were siblings when all three live in `spring-core`; the lint's link check only ever scanned `CLAUDE.md`, so rule-file links were unverified. Every relative markdown link across all 8 plugins now resolves.

### Changed

- **`CLAUDE.md` files rewritten** to carry only what the rules and frontmatter cannot: the plugin's boundary, the non-obvious composition decisions, and the routing between siblings. Removed from all eight: the layout table (agents, commands, and skills already surface their own descriptions), the "Conventions imported as rules" bullet summary of files imported in full immediately below, and the "When editing this plugin" authoring instructions.
- **Rules rewritten to the keep/cut test.** Cut: naming conventions, `data class`/`val` preference, standard HTTP status semantics, REST resource shapes, and the illustrative code blocks for idioms a model already writes. Kept and in places sharpened: the 12 forbidden coroutine patterns (with the four that compile-and-pass-tests called out), Liquibase checksum immutability, jOOQ `Record` containment, the Avro null-first union / enum-ordinal / missing-alias traps, the Apicurio v2-vs-v3 path trap, `forces replacement`, `for_each` reindex churn, memory-limit-equals-request, sync-status vs health-status, and the 152-FZ ⇄ GDPR divergence.
- **Agents no longer restate their own rules.** `test-writer` reproduced most of `rules/testing.md` including its code samples; `backend-implementer` restated the coroutine checklist and the hexagonal layer table; `code-reviewer` and `security-auditor` restated the severity tables their rule files define. Each now cites the rule and spends its words on what only it knows — its boundary, its order of operations, its escalations, and the failure mode it exists to prevent.
- **Skills keep their executable content and lose the ceremony.** The greps, the check tables, the JSON descriptors, and the resolution ladders are the value and are intact; the "When to Use" / "Do NOT" / "Output" scaffolding around them, and the worked output templates, are not.
- **Manifest descriptions cut from inventories to discovery text.** Each `plugin.json` and the matching `marketplace.json` entry ran 1,000–1,900 characters enumerating every agent, command, and skill — an inventory nobody browses. Now 400–620 characters saying what the plugin is for and what it refuses to do.
- **README** updated for the fourth design principle, with the plugin cards trimmed and the stale lint claim ("15 check families, 230+ checks") corrected to 340.

### Not verified

The plugins were not installed and exercised as part of this pass, and the bash inside skills is unchanged but untested. Pre-existing third-party claims were preserved rather than re-confirmed against upstream: the davidmc24 1.4.0 Kotlin task-wiring change, the Apicurio Registry v2/v3 URL split, and Nimbus decoder defaults.

## [0.5.0] — 2026-08-10

Consolidation wave. A redundancy review of all 18 plugins found two real defects and several capabilities implemented two or three times over. The marketplace collapses to **8 plugins / 30 agents** (was 18 / 45), with no capability removed — the library release track, all three QA output formats, and kotlin-extras are intact.

The organising principle: **an agent must earn its hop.** A subagent is right for bulk, isolatable, or differently-reasoned work; it is wrong for reference knowledge, because the subagent doesn't have your conversation. Five core "expert" agents were snippet libraries in agent clothing — their content is now `rules/`, loaded where the work happens. And **depth is a parameter, not a plugin boundary**: near-identical skills in two plugins were merged behind a mode argument.

### Fixed
- **`spring-core`'s `infra-expert` contradicted the infra wave.** It shipped a Kubernetes Deployment template with `image: <service>:latest`, no `resources` block, and no `securityContext` at all — output that `komdosh-dev-infra-kubernetes`'s own `k8s-resources.md` ("requests and limits are not optional"), `k8s-security.md` (restricted Pod Security Standards), and `infra-safety-scan` all correctly flag as violations. With both plugins installed, one agent generated exactly what another rejected. The agent is deleted; container/Compose knowledge moved to `core/rules/local-dev.md` (which now also mandates a non-root image UID, so the runtime's `runAsNonRoot` is satisfiable), and Kubernetes/Helm/ArgoCD/CI are explicitly out of scope there. `komdosh-dev-infra-k8s` is now the single authority.
- **The lifecycle gate map was blind to half the marketplace.** `lifecycle-status` hardcoded a 9-plugin detection list; the 9 plugins shipped since — avro, security, tasker, arch-planner, and all five infra plugins — were never detected, so their gates silently never appeared. It now enumerates every installed `komdosh-dev-*` plugin from disk, reports an undetectable plugin as UNKNOWN rather than N/A, and surfaces any installed plugin the gate table doesn't yet cover.

### Changed — plugin consolidation (18 → 8)
- **`komdosh-dev-spring-core`** absorbs `spring-events` and `spring-avro`. Event consumers and Avro schemas are implementation concerns bound to the same hexagonal and coroutine rules, and the Avro schemas produce the DTOs the consumers read.
- **`komdosh-dev-spring-quality`** (was `spring-qa`) absorbs `spring-security` and `spring-platform` — one plugin for "find out what's actually true about a finished service".
- **`komdosh-dev-spring-delivery`** (was `spring-release`) absorbs `spring-orchestrator`, `tasker`, and `arch-planner` — one pipeline from "a ticket exists" to "the release PR is open".
- **`komdosh-dev-revealer`** merges `kotlin-revealer` and `kotlin-doc-revealer`. Same machinery (cheapest-source ladder → rank → cite → name the gaps) over two source sets.
- **`komdosh-dev-infra-iac`** merges `infra-terraform` and `infra-yandex`. Yandex Cloud is a provider specialization, not a separate discipline — one author/reviewer pair with the YC resource and audit layers folded in, keeping the "who writes / who reviews" boundary intact instead of splitting it four ways.
- **`komdosh-dev-infra-k8s`** merges `infra-kubernetes` and `infra-argocd`. A Deployment and the Application that ships it are two halves of one change; an app that is Degraded because its pod is crashing is one diagnosis, not a hand-off.
- `komdosh-dev-kotlin-extras` and `komdosh-dev-infra-core` are unchanged.

### Changed — agent consolidation (45 → 32)
- `change-reviewer` + `service-readiness-auditor` → **`code-reviewer`** with `scope=diff|service`. The checklists overlapped almost entirely; only the scope differed. `/review` and `/service-health` both remain, targeting the two scopes.
- `terraform-author` + `yc-provisioner` → **`iac-author`**; `terraform-reviewer` + `yc-auditor` → **`iac-reviewer`**.
- `k8s-manifest-author` + `argocd-app-author` → **`k8s-author`**; `k8s-troubleshooter` + `argocd-diagnostician` → **`k8s-diagnostician`** (now read-only at the tool level); `k8s-hardening-auditor` → **`k8s-auditor`**, absorbing the `/argo-audit` hygiene checks.
- Deleted, with their knowledge moved to rules loaded in-context: `build-expert` → `rules/gradle-build.md`, `config-expert` → `rules/configuration.md`, `security-expert` → `rules/spring-security.md`, `observability-expert` → `rules/observability.md` (gaining the `Timer.recordSuspending` pattern), `infra-expert` → `rules/local-dev.md` + the infra plugins.
- Deleted, with their procedure moved into the command that already wrapped them: `adr-writer` → `/adr-new`, `migration-writer` → `/add-migration`, `requirements-analyst` → `/analyze-requirements`. Each was a one-artifact template behind an agent hop that discarded the conversation context holding the actual rationale.
- Deleted, with their procedure moved into the command that already wrapped them: `jira-task-coordinator` → `/jira-task`. The agent's whole job was orchestration the command performs directly — format a memo, hand it to `lifecycle-supervisor`, transition the ticket on the result.
- Converted to a skill: `changelog-writer` → the `write-changelog` skill. It is a deterministic git-log-to-markdown transform that `release-coordinator` calls mid-pipeline, so as an agent it was a nested subagent hop inside an already-agentic flow — a context handoff bought with no isolation. `/changelog` and `release-coordinator` both run it inline now.

### Changed — deduplication
- **PII scanning was implemented three times.** `core/pii-safety-scan` and `spring-security/scan-pii-exposure` shared an identical field lexicon and four of seven families, with the second a strict superset — and each file described the other as its "fast / audit-grade counterpart", rationalising the duplication rather than resolving it. Now one `core/pii-safety-scan` with `depth=fast|audit`. `infra-core/pii-exposure-scan` stays: it covers a genuinely different surface (data at rest, residency, backups).
- **`/qa-plan` + `/qa-postman` + `/qa-console` → `/qa [plan|postman|console|all]`.** The three commands had structurally identical bodies and each re-ran `discover-api-surface`, so three artifacts could describe three different snapshots of the API. Now one discovery pass; `all` runs the writers in parallel over disjoint paths. The three writer agents remain — their output specs (a markdown checklist, a Postman v2.1 schema, an HTML application) genuinely differ, sharing about 15 lines out of 560.

### Changed — other
- Merged agent descriptions trimmed; the always-loaded agent + skill description budget is ~8.9k tokens (was ~10.7k) for the full suite — and far less in practice, since covering one service now takes 4 plugins instead of 13.
- `marketplace.json` rebuilt for 8 plugins; the `messaging` and `architecture` categories are retired.
- README rewritten for the 8-plugin layout, with the design principles that keep it small.

## [0.4.0] — 2026-07-01

Infrastructure wave. A second engineering domain joins the Kotlin + Spring suite: a foundation-plus-specialists suite for infrastructure-as-code and GitOps, mirroring the core+companions design. Five new plugins (13 → 18); the four specialists depend on the new infra foundation, not on the Spring core, so they run in a pure-infra repo with no Kotlin present.

### Added
- **New plugin: `komdosh-dev-infra-core` (0.1.0)** — must-have infra foundation. Two read-only agents (`infra-reviewer` — six-dimension change review: correctness · blast radius · reversibility · security · drift · cost; `secrets-sentinel` — multi-layer secrets-leak audit reporting by location + type, never the value), `/infra-review` · `/infra-map` · `/secrets-audit`, two internal skills (`discover-infra-context` repo-mapper, `infra-safety-scan` grep preflight), five rule documents (`iac-safety`, `secrets-hygiene`, `gitops-principles`, `environment-promotion`, `infra-review`), a millisecond-scale `infra-context.sh` SessionStart hook that injects the plan→review→apply contract in an infra repo (silent no-op elsewhere), and a `settings.recommended.json` that allows read-only infra commands and denies every mutating one (`apply`/`destroy`/`sync`/`delete`).
- **New plugin: `komdosh-dev-infra-terraform` (0.1.0)** — Terraform/OpenTofu. `terraform-author` + read-only `terraform-reviewer`, the `discover-terraform-layout` and `verify-plan-safety` skills (the latter classifies every plan action SAFE/REVIEW/DANGEROUS and flags `forces replacement` on stateful resources before apply), three rules (`terraform-style`, `terraform-state-safety`, `terraform-plan-review`), and `/tf-module` · `/tf-plan-review` · `/tf-audit`. Uses the Terraform registry MCP for current versions; never runs apply/destroy.
- **New plugin: `komdosh-dev-infra-kubernetes` (0.1.0)** — three agents (`k8s-manifest-author`, read-only `k8s-hardening-auditor` against Pod Security Standards restricted, `k8s-troubleshooter` root-causing CrashLoopBackOff/ImagePullBackOff/OOMKilled/Pending/probe failures), the `discover-k8s-workloads` and read-only `probe-cluster-state` skills, three rules (`k8s-manifests`, `k8s-security`, `k8s-resources`), and `/k8s-manifest` · `/k8s-audit` · `/k8s-debug`. Audits the rendered (`kustomize build`/`helm template`) manifests so overlay regressions are caught; never mutates a cluster.
- **New plugin: `komdosh-dev-infra-argocd` (0.1.0)** — `argocd-app-author` + read-only `argocd-diagnostician` (separates sync status from health status; git-based remediation only), the `discover-argocd-apps` and `probe-app-health` skills, two rules (`argocd-applications`, `gitops-delivery`), and `/argo-app` · `/argo-diagnose` · `/argo-audit`. Rollback is git revert; the cluster is never mutated out of band.
- **New plugin: `komdosh-dev-infra-yandex` (0.1.0)** — `yc-provisioner` + read-only `yc-auditor` for Yandex Cloud on top of the Terraform plugin's generic HCL discipline. The `discover-yc-context` and `verify-yc-resources` skills, three rules (`yc-terraform`, `yc-security`, `yc-managed-services`), and `/yc-provision` · `/yc-audit` · `/yc-context`. Secure-and-HA by default (regional Managed K8s masters, HA managed databases with backups + `prevent_destroy`, Lockbox + KMS, least-privilege IAM, Object Storage state); never applies.

### Added — PII & data protection (152-FZ + GDPR), folded across four plugins
- **`komdosh-dev-infra-core`**: `data-protection-auditor` agent (read-only; PII across the data lifecycle — classification, encryption at rest/in transit, least-privilege access, network isolation, PII in backups/logs/events/object-storage, retention & erasure reachability, data-plane audit trails — never printing the personal data), the `pii-exposure-scan` grep preflight skill, `/pii-audit` command, and `rules/pii-data-protection.md` (the canonical cross-infra rule: classification taxonomy, the controls, PII's back doors, retention/erasure, and the **152-FZ localization vs GDPR cross-border-transfer divergence** that forces jurisdiction-partitioned data stores). The SessionStart hook now also injects the PII non-negotiables.
- **`komdosh-dev-infra-yandex`**: `rules/yc-data-residency.md` (152-FZ localization made concrete for YC — Russian personal data recorded and stored in `ru-central1`, backups/replicas in-region, PII-at-rest controls, and the EU+RU commingling risk against GDPR transfer). `verify-yc-resources` and `yc-auditor` gained a PII-residency dimension (localization, unencrypted/public PII stores, commingling flagged for legal review).
- **`komdosh-dev-spring-core` (→ 0.4.0)**: `rules/pii-handling.md` (application-layer discipline — classify PII at the type level with redacting `toString()`, never log/trace/tag raw PII, minimise/mask/tokenise, field-level encryption + crypto-shred for special categories, PII-in-events as a documented decision, build erasure/access/retention in from day one) and the fast `pii-safety-scan` preflight skill (now in the SessionStart preflight map, run alongside `coroutine-safety-scan`).
- **`komdosh-dev-spring-quality` (→ 0.3.0)**: `/pii-leakage-check` command + `scan-pii-exposure` skill + a PII-exposure category in `rules/security-audit.md`; the `security-auditor` now runs a fourth sub-audit over the data-in-motion surface (logs, traces/metrics/MDC, `@ExceptionHandler` bodies, response DTOs, event payloads, un-redacted PII value classes) and never prints a personal-data value.
- **Split of concern**: PII **in motion** (service code) is the Spring suite's job; PII **at rest** (encryption, residency, backup erasure) is the infra suite's `/pii-audit`. Each wave's PII coverage is self-contained, so Spring-only and infra-only users are both covered. All content is framed as engineering obligations, explicitly **not legal advice**.

### Changed
- Marketplace `description` and `version` updated for the two-wave suite (18 plugins). A new `infrastructure` category joins the existing eight. Touched plugins gained `pii` / `data-protection` / `data-residency` keywords and tags.

## [0.3.0] — 2026-06-10

First-class plugin engineering wave. Every plugin bumped one minor (0.1.0 → 0.2.0, 0.2.0 → 0.3.0).

### Added
- **New plugin: `komdosh-dev-spring-delivery` (0.1.0)** — `/implementation-plan <service>` creates a whole-service implementation agentic plan from the company architecture repository. Ships the `implementation-planner` agent (opus), the internal `discover-architecture-context` skill (arch-repo resolution ladder with code-RAG MCP degraded mode, tiered evidence inventory T0–T7, gap reporting), and `rules/agentic-plan.md` (executor mapping onto marketplace agents/commands + frozen fallback plan contract). Defers to the architecture repo's own `plan-service-implementation` contract when present; plans land in `docs/plans/` where core's `/continue-plan` resumes.
- `dependencies` in every companion plugin's `plugin.json` — installing any plugin now auto-installs `komdosh-dev-spring-core` at the same scope; `komdosh-dev-spring-delivery` additionally pulls `komdosh-dev-spring-delivery`.
- `category` + `tags` on every `marketplace.json` entry, marketplace-level `description`/`version`, and `metadata.pluginRoot` for terse sources.
- **core**: `session-context.sh` SessionStart hook — when the project has a `service.yaml`, injects the service summary and the mandatory preflight-skill map as `additionalContext` before the first prompt. Runs once per session, millisecond-scale, silent no-op elsewhere.
- `disallowedTools` on the read-only agents (`change-reviewer`, `service-readiness-auditor`, `security-auditor`, `knowledge-revealer`, `doc-revealer`) — "read-only" is now enforced at the tool layer.
- `skills:` preloading on 11 specialist agents (e.g. `backend-implementer` → `coroutine-safety-scan` + `module-boundary-check`; `security-auditor` → all three audit skills) — no discovery round-trips.
- `user-invocable: false` on the 18 internal skills, keeping the `/` menu down to what users should actually type.
- `allowed-tools` on the read-only core scan skills (`Grep, Glob, Read`, plus scoped `Bash(git …:*)`/`Bash(find:*)` where needed) — preflight scans no longer permission-prompt.
- Lint check families 10–15 in `tools/lint-marketplace.sh`: plugin.json completeness + dependency resolution, marketplace category/tags, agent model-alias enforcement, hooks.json hygiene (`${CLAUDE_PLUGIN_ROOT}` + timeout), frontmatter description budget (1536-char listing cap), and hook JSON-protocol compliance.

### Removed
- **Hook policy: only millisecond-scale, high-value hooks survive.** Dropped `qa-staleness-warn.sh` (fired on every Edit/Write; staleness is already surfaced by core's `service-readiness-auditor`) and `pre-tag-validation.sh` (fired on every Bash call; the pre-tag discipline is owned by `release-coordinator` and `rules/release-engineering.md`). The marketplace now ships exactly two hooks, both in core: the once-per-session `session-context.sh` and the migration-register reminder, which exits immediately unless the edited file is a `db/changelog/V*.sql`. No per-Bash-call hooks, no test-running hooks, nothing long-running.

### Fixed
- **The surviving migration-register hook emitted its hint to stderr with exit 0 — a channel the model never sees on PostToolUse.** It now emits the Claude Code JSON output protocol (`hookSpecificOutput.additionalContext`) on stdout, so the Liquibase-registration reminder actually reaches the model.

### Changed
- The two remaining hooks declare explicit `timeout` and `statusMessage`.
