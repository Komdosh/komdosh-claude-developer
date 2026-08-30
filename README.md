<div align="center">

# komdosh-claude-developer

**A Claude Code marketplace of opinionated plugins that turn Claude into a senior backend engineer for Kotlin + Spring WebFlux services — and a senior platform engineer for the Terraform / Kubernetes / ArgoCD / Yandex Cloud infrastructure they run on.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Marketplace](https://img.shields.io/badge/Claude%20Code-Marketplace-blueviolet)](https://docs.claude.com/en/docs/claude-code)
[![8 plugins](https://img.shields.io/badge/plugins-8-2ea44f)](.claude-plugin/marketplace.json)
[![Stack: Kotlin · Spring WebFlux · coroutines](https://img.shields.io/badge/stack-Kotlin%20%C2%B7%20Spring%20WebFlux%20%C2%B7%20coroutines-orange)](plugins/komdosh-dev-spring-core/rules/spring-webflux.md)
[![Infra: Terraform · Kubernetes · ArgoCD · Yandex Cloud](https://img.shields.io/badge/infra-Terraform%20%C2%B7%20K8s%20%C2%B7%20ArgoCD%20%C2%B7%20Yandex%20Cloud-blue)](plugins/komdosh-dev-infra-core/rules/iac-safety.md)

[**Install**](#install-in-30-seconds) · [**Plugins**](#what-ships-in-this-marketplace) · [**Anatomy of a task**](#anatomy-of-a-development-task) · [**Conventions**](#conventions-enforced-by-core) · [**Authoring**](#authoring-plugins-in-this-marketplace)

</div>

---

> **One marketplace, eight focused plugins across two waves.** Install only what you need.

`komdosh-claude-developer` spans two engineering domains. The **Kotlin + Spring wave** (5 plugins) shares an opinionated backend stack — Kotlin + Spring WebFlux + coroutines, hexagonal architecture, RFC 9457 errors, jOOQ + Liquibase, Micrometer + OpenTelemetry. The **infrastructure wave** (3 plugins) is a foundation-plus-specialists suite for infrastructure-as-code and GitOps. The two waves are independent: the infra plugins carry no Kotlin/Spring assumption and run in a pure-infra repo.

## What ships in this marketplace

### Kotlin + Spring wave

| Plugin | What it adds | Install when |
|---|---|---|
| **[komdosh-dev-spring-core](plugins/komdosh-dev-spring-core/)** | 8 agents · 13 commands · 11 skills · 19 rules · 2 hooks. Writing, verifying, and reviewing code inside one service — including its Kafka/SQS/RabbitMQ consumers and Avro schemas, which answer to the same hexagonal and coroutine rules. Six grep-based preflight skills (coroutine-safety, module-boundary, PII, liquibase-immutability, jOOQ-freshness, pre-edit-impact) catch in seconds what would otherwise cost a full Gradle cycle. | **Always.** Every other plugin requires it. |
| **[komdosh-dev-spring-quality](plugins/komdosh-dev-spring-quality/)** | 5 agents · 7 commands · 4 skills. `/security-audit` and its four narrowed entry points — the route ↔ `SecurityWebFilterChain` coverage matrix that finds the handlers nobody knows are open, RFC 9457 error hygiene, JWT/JWK validation, and personal data in motion. `/audit-leaks` for vendor coupling in `application/`/`domain/`. `/qa` produces a checklist, a Newman-runnable collection, and a single-file HTML console from **one** API-surface discovery — three artifacts of the same snapshot. | You want a defensive audit before shipping, or QA artifacts a non-CLI teammate can run. |
| **[komdosh-dev-spring-delivery](plugins/komdosh-dev-spring-delivery/)** | 4 agents · 12 commands · 11 skills. Between "a ticket exists" and "the release PR is open": Jira entry, architecture-repo-driven implementation plans, a `/lifecycle` gate map computed from **real git state** with a next-action recommendation, and two-track release engineering — services get a rollback playbook, libraries get an **ABI-load-bearing** version bump where a breaking delta forces major regardless of commit prefixes. Never deploys, pushes tags, or merges. | You want lifecycle guidance, Jira-driven entry, or you're cutting a release. |
| **[komdosh-dev-revealer](plugins/komdosh-dev-revealer/)** | 2 agents · 2 commands · 2 skills. Retrieval before invention. `/reveal` over ADRs, specs, plans, `// DECISION` comments, commit archaeology, and any RAG/MCP knowledge base. `/doc-reveal` resolves documentation cheapest-first — in-repo KDoc → project docs → cache → MCP → canonical web docs → jar listings → decompilation last — and caches it. Both cite their source; **a gap is a result, an invented citation is the failure.** | You have a non-trivial `docs/adr/`, RAG/MCP wired up, or you keep diving into jars for a signature. |
| **[komdosh-dev-kotlin-extras](plugins/komdosh-dev-kotlin-extras/)** | 3 agents · 3 commands. `/upgrade` (one library at a time, changelog-aware), `/detect-flakes` (re-run + classify + route), `/load-test-new` (Gatling scaffolder). | When the specific need arises. |

### Infrastructure wave

| Plugin | What it adds | Install when |
|---|---|---|
| **[komdosh-dev-infra-core](plugins/komdosh-dev-infra-core/)** | 3 read-only agents · 4 commands · 3 skills · 6 rules · 1 hook. The foundation: a six-dimension change reviewer, a multi-layer secrets sweep that reports location and **type, never the value**, and a data-protection auditor covering the PII lifecycle under 152-FZ **and** GDPR without printing the data. A SessionStart hook injects the plan→review→apply contract; the recommended permission set denies every mutating infra command. | **Always, for infra work.** Both specialists require it. No cloud or language assumption. |
| **[komdosh-dev-infra-iac](plugins/komdosh-dev-infra-iac/)** | 2 agents · 6 commands · 4 skills · 7 rules. Terraform/OpenTofu **with the Yandex Cloud layer built in** — YC is a provider specialization, not a separate discipline, so one author/reviewer pair handles both. `verify-plan-safety` classifies every plan action SAFE/REVIEW/DANGEROUS and flags `forces replacement` on stateful resources **before** apply, because an additive-looking source diff can still destroy a database. Never runs apply or destroy. | You provision with Terraform/OpenTofu, on Yandex Cloud or anywhere else. |
| **[komdosh-dev-infra-k8s](plugins/komdosh-dev-infra-k8s/)** | 3 agents · 6 commands · 4 skills · 5 rules. Kubernetes **and its ArgoCD delivery** — a Deployment and the Application that ships it are two halves of one change, so one author owns both. Author and auditor work on the **rendered** manifest, since an overlay can silently drop a hardening patch the base contains. The diagnostician separates *sync* status from *health* status and refuses workarounds that hide a symptom. Never mutates a cluster; rollback is git revert. | You run workloads on Kubernetes, with or without ArgoCD. |

Total: **30 agents · 53 commands · 39 skills · 42 rule documents · 3 hooks** across eight plugins. Each is independently installable. **PII / data protection** (152-FZ + GDPR) spans both waves — data *in motion* through application code is the Spring wave's job (`pii-safety-scan`, `/pii-leakage-check`); data *at rest* — encryption, residency, retention, erasure — is the infra wave's (`/pii-audit`, `rules/yc-data-residency.md`).

## Design principles

The marketplace is deliberately small. Three rules keep it that way:

**An agent must earn its hop.** A subagent is right when the work is bulk, isolatable, or needs a different reasoning mode. It is wrong for reference knowledge — the subagent doesn't have your conversation, so dispatching one to "add a config property" costs more context than it saves. Knowledge that reads like a snippet library belongs in `rules/`, loaded where the work happens. That distinction is why core has 8 agents and 19 rules rather than the reverse.

**Depth is a parameter, not a plugin boundary.** One PII scan with `depth=fast|audit`, not two near-identical skills in two plugins. One reviewer with `scope=diff|service`, not two agents sharing a checklist. Duplicated logic drifts; parameters don't.

**Authors write, reviewers critique, and the two never overlap.** Every audit agent carries `disallowedTools` so read-only is a tool-level guarantee, not a system-prompt aspiration. Nothing in this marketplace runs `terraform apply`, `kubectl apply`, `argocd sync`, `gradlew publish` without explicit confirmation, or `git push --tags` at all.

**Write down what a good model gets wrong, not what it already knows.** A rule earns its place by naming a project-specific decision, a non-obvious trap, a hard prohibition, or a routing boundary. Restating idiomatic Kotlin, standard REST semantics, or a code sample of a common idiom costs context on every session and teaches nothing — so it isn't here.

## First-class plugin engineering

- **Declared dependencies** — every companion plugin's `plugin.json` names `komdosh-dev-spring-core` (or `komdosh-dev-infra-core`), so "requires core" is machine-enforced rather than prose.
- **Categories + tags** — `marketplace.json` classifies every plugin (`foundation` / `quality` / `workflow` / `knowledge` / `maintenance` / `infrastructure`) with search tags.
- **Minimal, millisecond-scale hooks** — three, all deliberately cheap, all emitting the JSON output protocol (`hookSpecificOutput.additionalContext` on stdout — the only exit-0 channel the model actually sees), with explicit `timeout`s. No per-Bash-call hooks, nothing long-running.
- **Read-only agents are enforced** — `code-reviewer`, `security-auditor`, both revealers, and every infra reviewer/auditor/diagnostician carry `disallowedTools`. The PII auditors additionally never print a personal-data value; findings are location + field only.
- **Skill preloading** — agents declare `skills:` frontmatter, eliminating discovery round-trips.
- **Internal skills hidden from the `/` menu** — skills that exist to serve commands and agents are `user-invocable: false`, so the slash menu shows only what you should type.
- **Pre-permitted scan skills** — read-only preflights declare `allowed-tools` so they run without permission prompts.
- **Self-linting** — `tools/lint-marketplace.sh` runs 15 check families across 340 checks (JSON validity, frontmatter completeness on agents, commands, and skills, dependency resolution, model-alias enforcement, hook JSON-protocol compliance, description char budgets against the 1536-char listing cap, the `set -e` + pipefail grep-pipeline bug class, …). Run it before every commit.

## Install in 30 seconds

Inside Claude Code:

```text
/plugin marketplace add komdosh/komdosh-claude-developer
/plugin install komdosh-dev-spring-core@komdosh-claude-developer       # always, for Kotlin/Spring work
/plugin install komdosh-dev-spring-quality@komdosh-claude-developer    # security + PII audits, QA artifacts, vendor-leak audit
/plugin install komdosh-dev-spring-delivery@komdosh-claude-developer   # lifecycle gates, Jira entry, planning, releases
/plugin install komdosh-dev-revealer@komdosh-claude-developer          # /reveal and /doc-reveal
/plugin install komdosh-dev-kotlin-extras@komdosh-claude-developer     # /upgrade /detect-flakes /load-test-new
# --- infrastructure wave (independent of the Kotlin/Spring wave) ---
/plugin install komdosh-dev-infra-core@komdosh-claude-developer        # always, for infra work
/plugin install komdosh-dev-infra-iac@komdosh-claude-developer         # Terraform / OpenTofu + Yandex Cloud
/plugin install komdosh-dev-infra-k8s@komdosh-claude-developer         # Kubernetes + ArgoCD
/plugin
```

The last command opens the plugin manager — verify each is **Installed** and **Enabled**.

> Installing any companion plugin auto-installs its foundation at the same scope via `dependencies`, so the explicit core installs above are belt-and-braces.

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

Merge [`plugins/komdosh-dev-spring-core/settings.recommended.json`](plugins/komdosh-dev-spring-core/settings.recommended.json) into your consumer project's `.claude/settings.json` so agents aren't prompted for routine `./gradlew`, `git`, and `docker compose` invocations. For infra repos, merge [`plugins/komdosh-dev-infra-core/settings.recommended.json`](plugins/komdosh-dev-infra-core/settings.recommended.json) — it allows read-only `terraform plan` / `kubectl get` / `helm template` / `argocd app diff` / `yc config` and **denies every mutating command** (`apply` / `destroy` / `sync` / `delete`), keeping those behind an explicit human decision.

</details>

<details>
<summary><strong>Updating, disabling, removing</strong></summary>

```text
/plugin marketplace update komdosh-claude-developer
/plugin disable <plugin-name>@komdosh-claude-developer
/plugin enable  <plugin-name>@komdosh-claude-developer
/plugin uninstall <plugin-name>@komdosh-claude-developer
/reload-plugins
```

</details>

### Choose a scope

Claude Code asks where to install. Pick deliberately:

- **User scope** (default) — every project on your machine. `~/.claude/settings.json`.
- **Project scope** — committed to the repo. `.claude/settings.json`. Everyone who clones gets it.
- **Local scope** — only you, only this repo. `.claude/settings.local.json` (gitignored).

## Why split into plugins at all

| Pain | What this marketplace does about it |
|---|---|
| One huge plugin clutters the picker with agents you'll never use — and every agent description is context you pay for on every session | Eight focused plugins. Pick what fits your service and your infra; the rest costs you nothing. |
| `runBlocking` in production WebFlux, `@Transactional` on `suspend fun`, MDC across suspension | [`rules/kotlin-coroutines.md`](plugins/komdosh-dev-spring-core/rules/kotlin-coroutines.md) lists 12 forbidden patterns; the `coroutine-safety-scan` skill catches them in seconds |
| Generated migrations clash with the team's checksum-based history | [`/add-migration`](plugins/komdosh-dev-spring-core/commands/add-migration.md) emits idempotent Liquibase formatted SQL with `--changeset` headers; `liquibase-changeset-immutability` catches edits to applied changesets via git history |
| New endpoints leak persistence IDs, return raw exception messages, or mix HTTP concerns into the domain | The `api-conventions` + `error-handling` + `hexagonal` triad is loaded into every session |
| Architectural decisions get lost between Slack and code | [`/adr-new`](plugins/komdosh-dev-spring-core/commands/adr-new.md) checks whether an ADR is warranted, then writes `docs/adr/NNNN-<slug>.md` with status, alternatives, and trade-offs |
| Application code gets tangled with Micrometer / jOOQ / Reactor / Jackson types directly | `/audit-leaks` finds them, then optionally extracts abstractions into a `common/` module |
| Manual QA is ad-hoc; no smoke suite for the team | `/qa all` generates a checklist, a Newman collection, and a self-contained HTML tester from your controllers — one discovery pass, three artifacts of the same snapshot |
| One agent does everything and forgets half of it | 30 agents that **delegate** instead of overreach — an author writes, a separate read-only reviewer critiques |

## Anatomy of a development task

A typical "add an endpoint" task isn't one big agent improvising — it's a chain of narrow specialists handing off through skills. Run `/add-endpoint Order create` and this is what happens:

```text
/add-endpoint Order create
        │
        ├─[skill]─ read-service-context
        │           service.yaml + module layout + base package — once per session
        │
        ├─[skill]─ check-adr-required
        │           hard to reverse, with ≥2 reasonable alternatives?
        │           ├─ REQUIRED   → /adr-new writes docs/adr/NNNN-<slug>.md FIRST
        │           └─ NOT REQ'D  → continue
        │
        ├─[agent]─ backend-implementer
        │           controller (suspend fun, no Mono/Flux), DTO, application port,
        │           boot wiring — never touches tests, migrations, or Gradle
        │           auth changes follow rules/spring-security.md inline
        │
        ├─[agent]─ test-writer        ← delegated to, not embedded
        │           @WebFluxTest with @MockkBean; runTest unit tests via fakes
        │
        ├─[cmd]───  /add-migration    ← only if the change needs a schema column
        │           idempotent Liquibase formatted SQL + master-changelog registration
        │
        ├─[skill]─ coroutine-safety-scan · module-boundary-check · pii-safety-scan
        │           seconds-long greps, before the expensive step
        │
        └─[skill]─ run-verification
                    narrowest-first: :<module>:test → :boot:compileKotlin → detekt
                    never ./gradlew build when a narrower target works
```

Every step pulls in the matching `rules/*.md`. The controller can't return `Mono<T>`, the service can't put `@Transactional` on a `suspend fun`, the migration can't have a non-formatted SQL header, the test can't use `runBlocking` — all caught in the prompt, not in code review.

## Conventions enforced by core

Core's [`rules/*.md`](plugins/komdosh-dev-spring-core/rules/) files load into every session via its `CLAUDE.md`. Highlights:

| Rule | Notable | Enforces |
|---|---|---|
| [kotlin-coroutines.md](plugins/komdosh-dev-spring-core/rules/kotlin-coroutines.md) | 12 forbidden patterns: `runBlocking` in prod/tests, `@Transactional` on `suspend fun`, `withContext` inside `@Transactional`, MDC across suspension, `Thread.sleep`, JVM blocking primitives | Coroutine safety |
| [spring-webflux.md](plugins/komdosh-dev-spring-core/rules/spring-webflux.md) | Every handler `suspend fun`; never `Mono`/`Flux` from a controller; extract auth/correlation context **before** `withContext` | Reactive correctness |
| [hexagonal.md](plugins/komdosh-dev-spring-core/rules/hexagonal.md) | Module dependency direction enforced by ArchUnit; `adapters/inbound` cannot import `adapters/outbound` | Architecture |
| [domain-purity.md](plugins/komdosh-dev-spring-core/rules/domain-purity.md) | Banned imports in `domain/`/`application/`; `@JvmInline value class` for every domain ID | Domain isolation |
| [api-conventions.md](plugins/komdosh-dev-spring-core/rules/api-conventions.md) | `/api/v<N>/<resource-plural>`, RFC 9457 errors, never expose domain entities | HTTP contract |
| [error-handling.md](plugins/komdosh-dev-spring-core/rules/error-handling.md) | `ProblemDetail` everywhere; never leak stack traces/SQL/internal IDs | Error safety |
| [persistence.md](plugins/komdosh-dev-spring-core/rules/persistence.md) | jOOQ DSL only; idempotent Liquibase; `TransactionalOperator.executeAndAwait`; outbox pattern | Persistence safety |
| [observability.md](plugins/komdosh-dev-spring-core/rules/observability.md) | Micrometer `<org>.<service>.<subject>.<verb>`, low-cardinality tags, OTel vendor-neutral, **no MDC in WebFlux/coroutine paths** | Observability |
| [pii-handling.md](plugins/komdosh-dev-spring-core/rules/pii-handling.md) | Classify PII at the type level with redacting `toString()`; never log/trace/tag raw PII; mask at the boundary; build erasure in from day one | Personal data |
| [testing.md](plugins/komdosh-dev-spring-core/rules/testing.md) | `runTest` never `runBlocking`; fakes over mocks; `Clock.fixed`; Testcontainers for outbound integration | Test discipline |
| [spring-security.md](plugins/komdosh-dev-spring-core/rules/spring-security.md) | Principal extracted before any dispatcher switch; 401 vs 403 as `problem+json`; `anyExchange().authenticated()` always last | Auth correctness |
| [local-dev.md](plugins/komdosh-dev-spring-core/rules/local-dev.md) | Compose runs dependencies with healthchecks and pinned tags; multi-stage Dockerfile with a non-root UID | Local + packaging |

Plus `event-consumers`, the three `avro-*` rules, `gradle-build`, `configuration`, and `code-style`.

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

If your service doesn't look like this yet, install core and run [`/service-health`](plugins/komdosh-dev-spring-core/commands/service-health.md) — it reports what's missing and offers to fix the BLOCKERs one at a time.

**The infrastructure wave assumes none of this.** `komdosh-dev-infra-*` works in a pure Terraform monorepo, a GitOps manifest repo, or a Yandex Cloud estate with no application code at all. Run [`/infra-map`](plugins/komdosh-dev-infra-core/commands/infra-map.md) to detect which IaC tools, clouds, and environments are present.

## Authoring plugins in this marketplace

Each plugin lives at `plugins/<plugin-name>/` with its own:

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Manifest (`name`, `version`, `description`, `author`, `dependencies`) |
| `CLAUDE.md` | Plugin-scoped guidance + `@rules/...` imports for the rules it ships |
| `agents/<name>.md` | Subagents with `name`, `model`, `description` frontmatter |
| `commands/<verb-noun>.md` | Slash commands — `description` frontmatter (what the `/` menu shows) + the orchestration |
| `skills/<name>/SKILL.md` | Mandatory checklists with `name`, `description` frontmatter |
| `rules/<file>.md` | Convention documents — must be `@rules/...`-imported in the plugin's CLAUDE.md to load at all |
| `hooks/hooks.json` + `hooks/*.sh` | Optional plugin-shipped hooks |

Before adding an agent, ask whether it should be a rule. Before adding a second variant of an existing agent or skill, ask whether the difference is a parameter.

The marketplace itself is described by [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) at the repo root.

There is no Gradle build, no test suite, and no CI for the plugins themselves. Verification is "does the prose still describe the agent's actual behaviour and the current rule references?" Each plugin's CLAUDE.md is the canonical map for that plugin.

For mechanical hygiene, `tools/lint-marketplace.sh` runs 15 check families (340 individual checks): JSON validity, frontmatter on every agent, command, and skill, markdown links resolve, hook bash syntax + executability, the `set -e` + pipefail grep-pipeline bug class, and drift checks like "plugin.json name matches its directory" and "marketplace.json points at directories that exist." Run it before commit; it exits non-zero on any failure.

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
