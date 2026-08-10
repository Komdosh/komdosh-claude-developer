# Changelog

All notable changes to this marketplace. Format follows [Keep a Changelog](https://keepachangelog.com/); the marketplace `version` in `.claude-plugin/marketplace.json` tracks the wave, individual plugins version independently.

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
