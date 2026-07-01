<div align="center">

# komdosh-claude-developer

**A Claude Code marketplace of opinionated plugins that turn Claude into a senior backend engineer for Kotlin + Spring WebFlux services — and a senior platform engineer for the Terraform / Kubernetes / ArgoCD / Yandex Cloud infrastructure they run on.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Marketplace](https://img.shields.io/badge/Claude%20Code-Marketplace-blueviolet)](https://docs.claude.com/en/docs/claude-code)
[![18 plugins](https://img.shields.io/badge/plugins-18-2ea44f)](.claude-plugin/marketplace.json)
[![Stack: Kotlin · Spring WebFlux · coroutines](https://img.shields.io/badge/stack-Kotlin%20%C2%B7%20Spring%20WebFlux%20%C2%B7%20coroutines-orange)](plugins/komdosh-dev-spring-core/rules/spring-webflux.md)
[![Infra: Terraform · Kubernetes · ArgoCD · Yandex Cloud](https://img.shields.io/badge/infra-Terraform%20%C2%B7%20K8s%20%C2%B7%20ArgoCD%20%C2%B7%20Yandex%20Cloud-blue)](plugins/komdosh-dev-infra-core/rules/iac-safety.md)

[**Install**](#install-in-30-seconds) · [**Plugins**](#what-ships-in-this-marketplace) · [**Anatomy of a task**](#anatomy-of-a-development-task) · [**Conventions**](#conventions-enforced-by-core) · [**Authoring**](#authoring-plugins-in-this-marketplace)

</div>

---

> **One marketplace, eighteen focused plugins across two waves.** Install only what you need.

`komdosh-claude-developer` is a **single-source Claude Code marketplace** spanning two engineering domains. The **Kotlin + Spring wave** (13 plugins) shares an opinionated backend stack (Kotlin + Spring WebFlux + coroutines, hexagonal architecture, RFC 9457 errors, jOOQ + Liquibase, Micrometer + OpenTelemetry). The **infrastructure wave** (5 plugins) is a foundation-plus-specialists suite for infrastructure-as-code and GitOps — `infra-core` (safety, secrets-hygiene, and promotion rules plus a cross-cutting reviewer and a secrets auditor) with Terraform/OpenTofu, Kubernetes, ArgoCD, and Yandex Cloud specialists on top. Pick the foundation of whichever wave you need plus whichever specialty workflows you actually use; the two waves are independent (the infra plugins carry no Kotlin/Spring assumption and run in a pure-infra repo).

## What ships in this marketplace

| Plugin | What it adds | Install when |
|---|---|---|
| **[komdosh-dev-spring-core](plugins/komdosh-dev-spring-core/)** | 15 agents · 10 commands · 9 skills · 11 rules · 2 hooks. Foundational dev workflow — `/add-endpoint`, `/add-migration`, `/review`, `/verify-service`, `/test-fix`, `/service-health`, `/adr-new`. Includes the 6 fast preflight skills (impact-check, coroutine-safety, module-boundary, liquibase-immutability, jooq-freshness, **pii-safety** — no raw personal data in logs/traces/events, mask at the boundary). | **Always.** Every other plugin in the marketplace requires it. |
| **[komdosh-dev-spring-events](plugins/komdosh-dev-spring-events/)** | `event-consumer-author` agent + `rules/event-consumers.md` — Kafka / SQS / RabbitMQ consumers with manual offset/ack, mandatory idempotency, transient-vs-poison error policy, schema-registry DTOs. | Your service consumes events. |
| **[komdosh-dev-spring-qa](plugins/komdosh-dev-spring-qa/)** | `/qa-plan` + `/qa-postman` + `/qa-console` — markdown checklist, Newman-runnable Postman collection, single-file HTML QA console. Staleness is surfaced by core's `service-readiness-auditor`, not a per-edit hook. | You ship to a team that does manual QA, or you want a smoke suite a non-CLI teammate can run. |
| **[komdosh-dev-spring-platform](plugins/komdosh-dev-spring-platform/)** | `/audit-leaks` + `platform-developer` agent + `rules/platform-module.md` — find vendor-coupling leaks (Micrometer, jOOQ, Reactor, Jackson, Kafka, R2DBC) in `application/`/`domain/` and stage abstractions into a `common/` module. | You're modernising or about to swap a vendor (metrics backend, broker, JSON library). |
| **[komdosh-dev-kotlin-extras](plugins/komdosh-dev-kotlin-extras/)** | `/upgrade` (one-library-at-a-time bumps with changelog awareness), `/detect-flakes` (re-run + classify + route), `/load-test-new` (Gatling scaffolder). | When the specific need arises. |
| **[komdosh-dev-spring-orchestrator](plugins/komdosh-dev-spring-orchestrator/)** | `/lifecycle` (status / next / orchestrate / audit) backed by the `lifecycle-supervisor` agent and the `lifecycle-status` skill. Computes a 16-gate pipeline (requirement → spec → ADR → plan → code → tests → migrations → preflight scans → verification → review → QA → readiness → PR), recommends the next action, and (with confirmation) chains the work toward "ready to ship". Detects which marketplace plugins are installed and skips inapplicable gates as N/A. | You want top-down lifecycle guidance for AI agents — orientation at the start of a session, gate enforcement before you ship. |
| **[komdosh-dev-kotlin-revealer](plugins/komdosh-dev-kotlin-revealer/)** | `/reveal <query>` (modes: survey / decision-trace / gap-find) backed by the `knowledge-revealer` agent and the `reveal-knowledge` skill. Multi-source retrieval over ADRs, specs, plans, notes, code-embedded `// DECISION:` / `// RATIONALE:` / `// NOTE:` / `// WHY:` comments, commit archaeology, and any RAG / MCP-backed knowledge bases (codebase-memory, lookstream-code-rag, Confluence/Notion/Linear, context7, ref-context). Synthesised answer with inline citations + gap list + one recommended next step. Read-only; gracefully degrades when MCP isn't configured. | You're an advanced AI user with RAG/MCP knowledge bases wired up, OR you have a non-trivial `docs/adr/` and want "have we decided this before" answered fast. |
| **[komdosh-dev-kotlin-doc-revealer](plugins/komdosh-dev-kotlin-doc-revealer/)** | `/doc-reveal <symbol\|topic\|library>` backed by the `doc-revealer` agent and the `reveal-source-docs` skill. Walks a 10-step ladder from cheapest to most expensive — in-repo KDoc/Javadoc → project `/docs/` → `~/.claude/docs-cache/` → MCP (codebase-memory, context7, ref-context) → canonical web URLs (docs.spring.io / javadoc.io / kotlinlang.org / GitHub) via WebFetch → WebSearch fallback → pre-indexed JAR listings → JAR decompilation as edge-case-only last resort. Caches resolved snippets so repeat queries are instant. Read-only on project source. | You want **API meaning / signatures**, not decision history. Stop diving into JARs first — let the agent target the cheapest doc source. |
| **[komdosh-dev-spring-release](plugins/komdosh-dev-spring-release/)** | Release engineering for **services** AND **shared libraries** — two tracks, one plugin. Auto-detects which track applies and runs the matching gates. Service track: `/release-prep` · `/changelog` · `/version-bump` · `/release-notes` · `/rollback-playbook` (forward-fix-aware). Library track: same plus `/abi-check` · `/publish-prep` · `/deprecate-api` (ABI-load-bearing semver). Ships `release-coordinator` + `changelog-writer` + `library-publisher` agents, six skills, and `rules/release-engineering.md`. Stops at "release PR open" + (rollback playbook \| ABI report); never deploys, pushes tags, or merges. | You're cutting a service release (deploy + rollback playbook), or publishing a shared Kotlin library (Maven Central / GitHub Packages). |
| **[komdosh-dev-spring-security](plugins/komdosh-dev-spring-security/)** | Defensive security audits — Spring-specific only (no commodity CVE/secret scanners). `/security-audit` composite + four narrowed entry points: `/auth-audit` (route ↔ `SecurityWebFilterChain` coverage matrix — flags unauthenticated `@RestController` handlers and shadowed permit-all rules), `/error-leakage-check` (RFC 9457 hygiene — no stack traces, SQL state, or persistence IDs in response bodies), `/jwt-rotation` (algorithm allowlist excludes `none`, JWK refresh, issuer + audience validators, no prod keys in test fixtures), `/pii-leakage-check` (personal-data exposure on the data-in-motion surface — raw PII in logs/traces/tags, error bodies, unmasked DTOs, event payloads, un-redacted PII value classes). Ships `security-auditor` agent, four skills, `rules/security-audit.md` classifying findings BLOCKER / WARNING / INFO. Read-only, never prints personal data; produces `docs/security/` reports. Distinct from core's `security-expert` which writes filters; this audits what's already there. PII **at rest** is the infra suite's `/pii-audit`. | You want a defensive audit before shipping a release, or you're after the Spring-specific findings (route↔filter coverage, RFC 9457 leakage, PII-in-logs) that generic security tools miss. |
| **[komdosh-dev-spring-avro](plugins/komdosh-dev-spring-avro/)** | Avro schema authoring + the autogenerated event-DTO pipeline. `avro-schema-author` agent + `/avro-new-event` (toolchain detect → schema author → codegen verify → registry-subject hand-off), `/avro-evolve` (compat-aware bump: additive in-place vs versioned-up v2), `/avro-audit` (BLOCKER/WARNING/INFO report on schemas, codegen, registry config). Ships `discover-avro-toolchain` + `verify-schema-compat` skills and three rules (schemas, codegen, registry). Defaults to davidmc24/gradle-avro-plugin + Confluent Schema Registry; detects Apicurio and avro4k. Enforces T-first nullable unions, required `doc` fields, `decimal`/`uuid`/`timestamp-millis` logical types, aliases on rename, `BACKWARD` compat default, `auto.register.schemas=false` in prod, no inlined registry credentials. Sits upstream of `komdosh-dev-spring-events` — that plugin's consumers read the DTOs this plugin produces. | Your service consumes or produces Avro-encoded events on Kafka (or any registry-backed broker), and you want the schema/codegen/registry pipeline to follow conventions instead of "whatever the first contributor typed." |
| **[komdosh-dev-arch-planner](plugins/komdosh-dev-arch-planner/)** | Architecture-driven implementation planning. `/implementation-plan <service>` resolves the company **architecture repository** (`--arch-repo=` flag → `.claude/architecture.yaml` → well-known paths → code-RAG MCP degraded mode), locates the service's architecture package, assembles a tiered evidence inventory (entry contracts → service package → domain → system → ADR constraints → business scope/roadmap → dev-ex standards), defers to the architecture repo's own `plan-service-implementation` contract as the output authority, probes current implementation state via graph/RAG MCP, and writes `docs/plans/<date>-<service>-implementation-plan.md` — ordered todos with priority, inputs, write scope, acceptance criteria, verification, dependencies, and an **Executor** column mapping each todo to the marketplace agent/command that runs it. Read-only on the architecture repo; plans land where core's `/continue-plan` resumes. | You keep ADRs and service architecture in a dedicated repo and want a definitive, evidence-cited agentic plan before bootstrapping a service like `social-media-processor`. |
| **[komdosh-dev-tasker](plugins/komdosh-dev-tasker/)** | Jira-driven task entry. `/jira-task [PROJ\|PROJ-123]` pulls one ticket from a project's Todo column via the Atlassian MCP, applies the first forward workflow transition (typically Todo → In Progress), hands the description to `lifecycle-supervisor` as the captured requirement, and on a clean gate map applies the second forward transition (typically → In Review) — otherwise asks the user. Forward-only walk: never hardcodes status names; trusts the project's Jira workflow. Ships `discover-jira-task` skill + `jira-task-coordinator` agent. Optional `.claude/jira.yaml` (`project: PROJ`) for project-key defaults. Refuses to run when no Atlassian MCP is detected. Explicit-trigger only. | You track work in Jira, have an Atlassian MCP server installed, and want the marketplace's lifecycle to start from `/jira-task PROJ` instead of pasting a ticket description into chat. |

### Infrastructure wave

| Plugin | What it adds | Install when |
|---|---|---|
| **[komdosh-dev-infra-core](plugins/komdosh-dev-infra-core/)** | 3 read-only agents · 4 commands · 3 skills · 6 rules · 1 hook. The infra foundation: `infra-reviewer` (six-dimension change review — correctness · blast radius · reversibility · security · drift · cost), `secrets-sentinel` (multi-layer secrets-leak audit reporting by location + type, never the value), and `data-protection-auditor` (PII across the data lifecycle — encryption, access, residency, retention, erasure — under 152-FZ + GDPR, never printing the personal data). `/infra-review`, `/infra-map`, `/secrets-audit`, `/pii-audit`; the `discover-infra-context` repo-mapper plus `infra-safety-scan` and `pii-exposure-scan` grep preflights; the `iac-safety` / `secrets-hygiene` / `gitops-principles` / `environment-promotion` / `infra-review` / `pii-data-protection` rules; a millisecond-scale SessionStart hook that injects the plan→review→apply contract; a read-only permission set that denies every mutating infra command. | **Always, for infra work.** The four infra specialists require it. Standalone — no cloud or language assumption. |
| **[komdosh-dev-infra-terraform](plugins/komdosh-dev-infra-terraform/)** | `terraform-author` + read-only `terraform-reviewer`. `verify-plan-safety` classifies every plan action SAFE/REVIEW/DANGEROUS and flags `forces replacement` on stateful resources **before** apply; `discover-terraform-layout` maps roots/backends/providers. Rules: `terraform-style`, `terraform-state-safety`, `terraform-plan-review`. `/tf-module`, `/tf-plan-review`, `/tf-audit`. Uses the Terraform registry MCP for current versions. Never runs apply/destroy. | You provision with Terraform or OpenTofu and want pinned, state-safe, plan-reviewed changes. |
| **[komdosh-dev-infra-kubernetes](plugins/komdosh-dev-infra-kubernetes/)** | 3 agents — `k8s-manifest-author` (hardened Deployments/StatefulSets, Kustomize/Helm, all three probes, PDB/HPA, graceful shutdown), read-only `k8s-hardening-auditor` (Pod Security Standards **restricted** + resources + reliability on the *rendered* manifests), `k8s-troubleshooter` (root-cause CrashLoopBackOff / ImagePullBackOff / OOMKilled / Pending / probe failures). Skills `discover-k8s-workloads` + read-only `probe-cluster-state`. Rules: `k8s-manifests`, `k8s-security`, `k8s-resources`. `/k8s-manifest`, `/k8s-audit`, `/k8s-debug`. Never mutates a cluster. | You run workloads on Kubernetes and want them secure-by-default, sized right, and diagnosable when they fail. |
| **[komdosh-dev-infra-argocd](plugins/komdosh-dev-infra-argocd/)** | `argocd-app-author` + read-only `argocd-diagnostician` (separates **sync status** from **health status**, root-causes OutOfSync/Degraded/sync-failure/drift, prescribes **git-based** remediation — never a manual `kubectl`). Skills `discover-argocd-apps` + `probe-app-health`. Rules: `argocd-applications`, `gitops-delivery`. `/argo-app`, `/argo-diagnose`, `/argo-audit`. Rollback is git revert; the cluster is never mutated out of band. | You deliver to Kubernetes with ArgoCD and want pinned, scoped, self-healing Applications and real GitOps discipline. |
| **[komdosh-dev-infra-yandex](plugins/komdosh-dev-infra-yandex/)** | `yc-provisioner` + read-only `yc-auditor` on top of the Terraform plugin's HCL discipline. VPC + per-zone subnets + default-deny security groups, Managed K8s (regional HA masters + autoscaling), Managed PostgreSQL/Kafka/Redis (HA + backups + `prevent_destroy`), Lockbox + KMS, Container Registry, least-privilege IAM, Object Storage state. Skills `discover-yc-context` + `verify-yc-resources`. Rules: `yc-terraform`, `yc-security`, `yc-managed-services`, `yc-data-residency` (**152-FZ localization to `ru-central1`** + the 152-FZ-vs-GDPR transfer divergence). `/yc-provision`, `/yc-audit`, `/yc-context`. Never applies. | Your cloud is Yandex Cloud and you want secure, HA, least-privilege, **residency-compliant** infra as reviewable Terraform. Pairs with the Terraform plugin. |

Total: **45 agents · 55 commands · 39 mandatory skills · 38 rule documents · 3 hooks** distributed across eighteen plugins (13 backend + 5 infrastructure). Each is independently installable. **PII / data protection** (152-FZ + GDPR) folds across four of them — app-layer handling and a leakage audit in `spring-core` + `spring-security`, and data-at-rest / residency / erasure auditing in `infra-core` + `infra-yandex`.

## First-class plugin engineering

The marketplace exploits the full Claude Code plugin surface, not just the markdown basics:

- **Declared dependencies** — every plugin's `plugin.json` carries a `dependencies` field, so installing any companion plugin auto-installs `komdosh-dev-spring-core` at the same scope (and `komdosh-dev-tasker` pulls in the orchestrator). The "requires core" prose is now machine-enforced.
- **Categories + tags** — `marketplace.json` classifies every plugin (`foundation` / `messaging` / `quality` / `architecture` / `workflow` / `knowledge` / `maintenance` / `infrastructure`) with search tags, and uses `metadata.pluginRoot` for terse sources.
- **Minimal, millisecond-scale hooks** — three, all deliberately cheap. In `komdosh-dev-spring-core`: a `SessionStart` hook (runs once per session; detects `service.yaml` and injects the service summary plus the mandatory preflight-skill map, so sessions start oriented with no `read-service-context` round-trip; silent no-op outside service repos) and the migration-register reminder (exits immediately unless the edited file is literally a `db/changelog/V*.sql`). In `komdosh-dev-infra-core`: a `SessionStart` hook that detects an infra repo (bounded, maxdepth-limited) and injects the plan→review→apply contract and the secrets/pinning non-negotiables (silent no-op outside infra repos). No per-Bash-call hooks, no test-running hooks, nothing long-running. All emit the JSON output protocol — `hookSpecificOutput.additionalContext` on stdout, the only exit-0 channel the model actually sees (stderr hints on exit 0 land in the transcript, not in Claude's context) — and declare explicit `timeout`s and `statusMessage`s.
- **Read-only agents are enforced, not promised** — audit/review agents (`change-reviewer`, `service-readiness-auditor`, `security-auditor`, `knowledge-revealer`, `doc-revealer`, and the infra reviewers `infra-reviewer`, `secrets-sentinel`, `data-protection-auditor`, `terraform-reviewer`, `k8s-hardening-auditor`, `argocd-diagnostician`, `yc-auditor`) carry `disallowedTools` frontmatter, so "read-only" is a tool-level guarantee rather than a system-prompt aspiration. The PII auditors additionally never print a personal-data value — findings are location + field only.
- **Skill preloading** — specialist agents declare `skills:` frontmatter (e.g. `backend-implementer` preloads `coroutine-safety-scan` + `module-boundary-check`; `security-auditor` preloads all three audit skills), eliminating discovery round-trips.
- **Internal skills hidden from the `/` menu** — the 31 skills that exist to serve commands and agents (`discover-api-surface`, `lifecycle-status`, the release gates, the infra discovery/scan skills, the PII scans, …) are `user-invocable: false`. Your slash-command menu shows only what you should type; the model can still invoke everything.
- **Pre-permitted scan skills** — the read-only preflight scans declare `allowed-tools` (e.g. `Grep, Glob, Read`, plus scoped `Bash(git log:*)` where needed) so they run without permission prompts.
- **Self-linting** — `tools/lint-marketplace.sh` runs 15 check families (JSON validity, frontmatter completeness, dependency resolution, model-alias enforcement, hook JSON-protocol compliance, description char budgets vs the 1536-char listing cap, the pipefail bug class, …). Run it before every commit.

## Install in 30 seconds

Inside Claude Code:

```text
/plugin marketplace add komdosh/komdosh-claude-developer
/plugin install komdosh-dev-spring-core@komdosh-claude-developer        # always
/plugin install komdosh-dev-spring-qa@komdosh-claude-developer          # if you want QA artifacts
/plugin install komdosh-dev-spring-events@komdosh-claude-developer      # if you consume Kafka/SQS/RabbitMQ
/plugin install komdosh-dev-spring-platform@komdosh-claude-developer    # if you're auditing vendor leaks
/plugin install komdosh-dev-kotlin-extras@komdosh-claude-developer      # for /upgrade /detect-flakes /load-test-new
/plugin install komdosh-dev-spring-orchestrator@komdosh-claude-developer # for /lifecycle and top-down workflow guidance
/plugin install komdosh-dev-kotlin-revealer@komdosh-claude-developer    # for /reveal and RAG/MCP-backed knowledge retrieval
/plugin install komdosh-dev-kotlin-doc-revealer@komdosh-claude-developer # for /doc-reveal — smart source-documentation discovery
/plugin install komdosh-dev-spring-release@komdosh-claude-developer      # for /release-prep, /changelog, /version-bump, /abi-check, /publish-prep, /deprecate-api, /rollback-playbook
/plugin install komdosh-dev-spring-security@komdosh-claude-developer     # for /security-audit, /auth-audit, /error-leakage-check, /jwt-rotation
/plugin install komdosh-dev-spring-avro@komdosh-claude-developer         # for /avro-new-event, /avro-evolve, /avro-audit and the avro-schema-author agent
/plugin install komdosh-dev-tasker@komdosh-claude-developer              # for /jira-task — Jira-driven entry into the lifecycle (requires Atlassian MCP)
/plugin install komdosh-dev-arch-planner@komdosh-claude-developer        # for /implementation-plan — architecture-repo-driven agentic plans for whole services
# --- infrastructure wave (independent of the Kotlin/Spring wave) ---
/plugin install komdosh-dev-infra-core@komdosh-claude-developer          # foundation for infra work — /infra-review, /infra-map, /secrets-audit (required by the four specialists)
/plugin install komdosh-dev-infra-terraform@komdosh-claude-developer     # for /tf-module, /tf-plan-review, /tf-audit — Terraform / OpenTofu
/plugin install komdosh-dev-infra-kubernetes@komdosh-claude-developer    # for /k8s-manifest, /k8s-audit, /k8s-debug — hardened manifests + troubleshooting
/plugin install komdosh-dev-infra-argocd@komdosh-claude-developer        # for /argo-app, /argo-diagnose, /argo-audit — ArgoCD GitOps delivery
/plugin install komdosh-dev-infra-yandex@komdosh-claude-developer        # for /yc-provision, /yc-audit, /yc-context — Yandex Cloud
/plugin
```

The last command opens the plugin manager — verify each is **Installed** and **Enabled**.

> Installing any companion plugin auto-installs `komdosh-dev-spring-core` at the same scope — each plugin declares it in `dependencies`, so the explicit core install above is belt-and-braces, not a requirement.

<details>
<summary><strong>Forks, self-hosted GitLab, or local clones</strong></summary>

```text
/plugin marketplace add https://github.com/<your-org>/<your-fork>.git
/plugin marketplace add /absolute/path/to/komdosh-claude-developer
```

</details>

<details>
<summary><strong>Pre-register the marketplace for a team (no interactive prompt)</strong></summary>

Add to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": ["komdosh/komdosh-claude-developer"]
}
```

</details>

<details>
<summary><strong>Recommended permissions</strong></summary>

Merge [`plugins/komdosh-dev-spring-core/settings.recommended.json`](plugins/komdosh-dev-spring-core/settings.recommended.json) into your consumer project's `.claude/settings.json` so agents don't get prompted for routine `./gradlew`, `git`, `docker compose`, etc. invocations. For infra repos, merge [`plugins/komdosh-dev-infra-core/settings.recommended.json`](plugins/komdosh-dev-infra-core/settings.recommended.json) instead (or as well) — it allows read-only `terraform plan`/`kubectl get`/`helm template`/`argocd app diff`/`yc config` and **denies every mutating command** (`apply`/`destroy`/`sync`/`delete`), keeping those behind an explicit human decision.

</details>

<details>
<summary><strong>Updating, disabling, removing</strong></summary>

```text
/plugin marketplace update komdosh-claude-developer    # refresh the catalogue
/plugin disable <plugin-name>@komdosh-claude-developer
/plugin enable  <plugin-name>@komdosh-claude-developer
/plugin uninstall <plugin-name>@komdosh-claude-developer
/reload-plugins                                          # apply edits without restart
```

</details>

### Choose a scope

Claude Code asks where to install. Pick deliberately:

- **User scope** (default) — every project on your machine. `~/.claude/settings.json`.
- **Project scope** — committed to the repo. `.claude/settings.json`. Everyone who clones gets it.
- **Local scope** — only you, only this repo. `.claude/settings.local.json` (gitignored).

## Why split into multiple plugins

| Pain | What this marketplace does about it |
|---|---|
| One huge plugin clutters the picker with agents you'll never use | Eighteen focused plugins across two waves. Pick what fits your service and your infra. |
| `runBlocking` in production WebFlux, `@Transactional` on `suspend fun`, MDC across suspension | [`rules/kotlin-coroutines.md`](plugins/komdosh-dev-spring-core/rules/kotlin-coroutines.md) lists 12 forbidden patterns; `coroutine-safety-scan` skill catches them in seconds |
| Generated migrations clash with the team's checksum-based history | [`migration-writer`](plugins/komdosh-dev-spring-core/agents/migration-writer.md) emits idempotent Liquibase formatted SQL with `--changeset` headers; the `liquibase-changeset-immutability` skill catches edits to applied changesets via git history |
| New endpoints leak persistence IDs, return raw exception messages, or mix HTTP concerns into the domain | The `rules/api-conventions.md` + `rules/error-handling.md` + `rules/hexagonal.md` triad in core is loaded into every session |
| Architectural decisions get lost between Slack and code | `/adr-new` checks if an ADR is warranted, then delegates to `adr-writer` — `docs/adr/NNNN-<slug>.md` with status, alternatives, trade-offs |
| Application code gets tangled with Micrometer / jOOQ / Reactor / Jackson types directly | `komdosh-dev-spring-platform`: `/audit-leaks` finds them, then optionally extracts abstractions into a `common/` module |
| Manual QA is ad-hoc; no smoke suite for the team | `komdosh-dev-spring-qa`: three commands generate a checklist, a Newman collection, and a self-contained HTML tester from your controllers |
| One agent does everything (writes code, tests, migrations, commits, infra) and forgets half of it | Across all plugins: 44 agents that **delegate** instead of overreach — an author writes, a separate read-only reviewer critiques; see [anatomy of a development task](#anatomy-of-a-development-task) |

## Anatomy of a development task

A typical "add an endpoint" task isn't one big agent improvising — it's a chain of narrow specialists that hand off through skills. Run `/add-endpoint Order create` (with core installed) and this is what actually happens:

```text
/add-endpoint Order create
        │
        ├─[skill]─ read-service-context
        │           reads service.yaml + module layout + base package — once per session
        │
        ├─[skill]─ check-adr-required
        │           is this hard to reverse, with ≥2 reasonable alternatives?
        │           ├─ REQUIRED   → adr-writer drafts docs/adr/NNNN-<slug>.md FIRST
        │           └─ NOT REQ'D  → continue
        │
        ├─[agent]─ backend-implementer
        │           writes controller (suspend fun, no Mono/Flux), DTO, application port,
        │           wires the boot module — never touches tests, migrations, or Gradle
        │
        ├─[agent]─ test-writer        ← delegated to, not embedded in backend-implementer
        │           writes @WebFluxTest with @MockkBean for the service,
        │           writes runTest unit tests for the application service via fakes
        │
        ├─[agent]─ migration-writer   ← only if the change needs a schema column
        │           writes idempotent Liquibase formatted SQL with --changeset header
        │           and registers it in db.changelog-master.yaml
        │
        ├─[agent]─ security-expert    ← only if auth scope changes
        │           updates SecurityWebFilterChain, returns problem+json on 401/403
        │
        └─[skill]─ run-verification
                    narrowest-first: :<module>:test → :boot:compileKotlin → detekt
                    fails loudly per module — never runs ./gradlew build when narrower works
```

Every step pulls in the matching `rules/*.md` from `CLAUDE.md`. The controller can't return `Mono<T>`, the service can't put `@Transactional` on a `suspend fun`, the migration can't have a non-formatted SQL header, the test can't use `runBlocking` — all caught in the prompt, not in code review.

The same delegation pattern shows up across every command and across every plugin in the marketplace.

## Conventions enforced by core

The 10 [`rules/*.md`](plugins/komdosh-dev-spring-core/rules/) files in core are loaded into every Claude session via core's `CLAUDE.md`. Each non-core plugin layers a small additional rule (events, platform-module). Highlights from core:

| Rule | Notable | Enforces |
|---|---|---|
| [kotlin-coroutines.md](plugins/komdosh-dev-spring-core/rules/kotlin-coroutines.md) | 12 forbidden patterns: `runBlocking` in prod/tests, `@Transactional` on `suspend fun`, `withContext` inside `@Transactional`, MDC across suspension, `Thread.sleep`, JVM blocking primitives | Coroutine safety |
| [spring-webflux.md](plugins/komdosh-dev-spring-core/rules/spring-webflux.md) | Every controller handler `suspend fun`; never `Mono`/`Flux` from a controller; extract auth/correlation context **before** `withContext` | Reactive correctness |
| [hexagonal.md](plugins/komdosh-dev-spring-core/rules/hexagonal.md) | Module dependency direction enforced by ArchUnit; `adapters/inbound` cannot import `adapters/outbound` | Architecture |
| [domain-purity.md](plugins/komdosh-dev-spring-core/rules/domain-purity.md) | Banned imports in `domain/`/`application/`: Spring, jOOQ, Kafka, R2DBC, Jackson, JPA. `@JvmInline value class` for every domain ID | Domain isolation |
| [api-conventions.md](plugins/komdosh-dev-spring-core/rules/api-conventions.md) | `/api/v<N>/<resource-plural>`, RFC 9457 `application/problem+json` errors, never expose domain entities | HTTP contract |
| [error-handling.md](plugins/komdosh-dev-spring-core/rules/error-handling.md) | `ProblemDetail` everywhere; never leak stack traces/SQL/internal IDs; sealed `DomainException` hierarchy with no Spring imports | Error safety |
| [persistence.md](plugins/komdosh-dev-spring-core/rules/persistence.md) | jOOQ DSL only; idempotent Liquibase formatted SQL; `TransactionalOperator.executeAndAwait` for coroutines; outbox pattern for events | Persistence safety |
| [observability.md](plugins/komdosh-dev-spring-core/rules/observability.md) | Micrometer naming `<org>.<service>.<subject>.<verb>`, low-cardinality tags, OTel vendor-neutral APIs, **no MDC in WebFlux/coroutine paths** | Observability |
| [testing.md](plugins/komdosh-dev-spring-core/rules/testing.md) | `runTest` (never `runBlocking`); fakes preferred over mocks; `Clock.fixed`; Testcontainers for outbound integration tests | Test discipline |
| [code-style.md](plugins/komdosh-dev-spring-core/rules/code-style.md) | `data class` + `val`, `sealed interface` for results, no `!!`, no magic numbers, ~300-line file split signal | Style |

## What this marketplace assumes about your service

A **hexagonal Kotlin service** with this leaf-module shape:

```
domain/  ←  application/  ←  adapters/{inbound,outbound}  ←  boot/
                                                            └  load-tests/
```

Plus:
- **Persistence**: jOOQ DSL, Liquibase formatted SQL, R2DBC for reactive access
- **Web**: Spring WebFlux + kotlinx-coroutines (no blocking on event-loop threads)
- **Tests**: Testcontainers (real Postgres for integration, not H2) + ArchUnit for module-boundary tests
- **Observability**: Micrometer + OpenTelemetry, vendor-neutral
- **Static analysis**: detekt + ktlint

If your service doesn't look like this yet, install core and run [`/service-health`](plugins/komdosh-dev-spring-core/commands/service-health.md) — it will tell you what's missing and offer to fix the BLOCKERs one at a time.

**The infrastructure wave assumes none of this.** `komdosh-dev-infra-*` makes no Kotlin/Spring assumption — it works in a pure Terraform monorepo, a GitOps manifest repo, or a Yandex Cloud estate with no application code at all. Run [`/infra-map`](plugins/komdosh-dev-infra-core/commands/infra-map.md) to have it detect which IaC tools, clouds, and environments are present and point you at the right specialist.

## Authoring plugins in this marketplace

Each plugin lives at `plugins/<plugin-name>/` with its own:

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Manifest (`name`, `version`, `description`, `author`) |
| `CLAUDE.md` | Plugin-scoped guidance + `@rules/...` imports for any rules the plugin ships |
| `agents/<name>.md` | Subagents with `name`, `model`, `description` frontmatter |
| `commands/<verb-noun>.md` | Slash commands (`# /<verb-noun>` heading + numbered orchestration steps) |
| `skills/<name>/SKILL.md` | Mandatory checklists with `name`, `description` frontmatter |
| `rules/<file>.md` | Convention documents — must be `@rules/...`-imported in the plugin's CLAUDE.md to actually load |
| `hooks/hooks.json` + `hooks/*.sh` | Optional plugin-shipped PreToolUse/PostToolUse hooks |

The marketplace itself is described by the single [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) at the repo root, which lists each plugin's `source` (subdirectory) and a one-line description for the plugin manager.

There is no Gradle build, no test suite, and no CI for the plugins themselves. Verification is "does the prose still describe the agent's actual behaviour and the current rule references?" Each plugin's CLAUDE.md is the canonical map for that plugin.

For mechanical hygiene, `tools/lint-marketplace.sh` runs 15 check families (330+ individual checks across all 18 plugins): JSON validity, frontmatter on every agent/skill, markdown links resolve, hook bash syntax + executability, the `set -e + pipefail` grep-pipeline bug class (caught real bugs in `release` and `core` after a smoke pass against three Spring repos), and a few drift checks like "plugin.json name matches its directory" and "marketplace.json points at directories that exist." Run it before commit; it exits non-zero on any failure.

### Local development

```bash
# point Claude Code at one plugin's working copy
claude --plugin-dir /absolute/path/to/komdosh-claude-developer/plugins/komdosh-dev-spring-core

# or symlink and reload
ln -s "$PWD/plugins/komdosh-dev-spring-core" ~/.claude/plugins/komdosh-dev-spring-core
# inside Claude Code:
/reload-plugins
```

## License

[MIT](LICENSE) — use it, fork it, ship it.

---

<div align="center">

Built for backend developers who want Claude to behave like the senior on their team — not like the intern who just discovered `runBlocking`.

</div>
