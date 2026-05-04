<div align="center">

# komdosh-claude-developer

**A Claude Code marketplace of opinionated plugins that turn Claude into a senior backend engineer for Kotlin + Spring WebFlux services.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Marketplace](https://img.shields.io/badge/Claude%20Code-Marketplace-blueviolet)](https://docs.claude.com/en/docs/claude-code)
[![7 plugins](https://img.shields.io/badge/plugins-7-2ea44f)](.claude-plugin/marketplace.json)
[![Stack: Kotlin · Spring WebFlux · coroutines](https://img.shields.io/badge/stack-Kotlin%20%C2%B7%20Spring%20WebFlux%20%C2%B7%20coroutines-orange)](plugins/komdosh-dev-spring-core/rules/spring-webflux.md)

[**Install**](#install-in-30-seconds) · [**Plugins**](#what-ships-in-this-marketplace) · [**Anatomy of a task**](#anatomy-of-a-development-task) · [**Conventions**](#conventions-enforced-by-core) · [**Authoring**](#authoring-plugins-in-this-marketplace)

</div>

---

> **One marketplace, seven focused plugins.** Install only what you need.

`komdosh-claude-developer` is a **single-source Claude Code marketplace**. It ships seven composable plugins that share an opinionated stack (Kotlin + Spring WebFlux + coroutines, hexagonal architecture, RFC 9457 errors, jOOQ + Liquibase, Micrometer + OpenTelemetry). Pick the foundation plus whichever specialty workflows you actually use — add the orchestrator for top-down lifecycle guidance, and the revealer for RAG/MCP-backed knowledge retrieval.

## What ships in this marketplace

| Plugin | What it adds | Install when |
|---|---|---|
| **[komdosh-dev-spring-core](plugins/komdosh-dev-spring-core/)** | 15 agents · 10 commands · 8 skills · 10 rules · 1 hook. Foundational dev workflow — `/add-endpoint`, `/add-migration`, `/review`, `/verify-service`, `/test-fix`, `/service-health`, `/adr-new`. Includes the 5 fast preflight skills (impact-check, coroutine-safety, module-boundary, liquibase-immutability, jooq-freshness). | **Always.** Every other plugin in the marketplace requires it. |
| **[komdosh-dev-spring-events](plugins/komdosh-dev-spring-events/)** | `event-consumer-author` agent + `rules/event-consumers.md` — Kafka / SQS / RabbitMQ consumers with manual offset/ack, mandatory idempotency, transient-vs-poison error policy, schema-registry DTOs. | Your service consumes events. |
| **[komdosh-dev-spring-qa](plugins/komdosh-dev-spring-qa/)** | `/qa-plan` + `/qa-postman` + `/qa-console` — markdown checklist, Newman-runnable Postman collection, single-file HTML QA console. Plus a hook that warns when artifacts go stale. | You ship to a team that does manual QA, or you want a smoke suite a non-CLI teammate can run. |
| **[komdosh-dev-spring-platform](plugins/komdosh-dev-spring-platform/)** | `/audit-leaks` + `platform-developer` agent + `rules/platform-module.md` — find vendor-coupling leaks (Micrometer, jOOQ, Reactor, Jackson, Kafka, R2DBC) in `application/`/`domain/` and stage abstractions into a `common/` module. | You're modernising or about to swap a vendor (metrics backend, broker, JSON library). |
| **[komdosh-dev-spring-extras](plugins/komdosh-dev-spring-extras/)** | `/upgrade` (one-library-at-a-time bumps with changelog awareness), `/detect-flakes` (re-run + classify + route), `/load-test-new` (Gatling scaffolder). | When the specific need arises. |
| **[komdosh-dev-spring-orchestrator](plugins/komdosh-dev-spring-orchestrator/)** | `/lifecycle` (status / next / orchestrate / audit) backed by the `lifecycle-supervisor` agent and the `lifecycle-status` skill. Computes a 16-gate pipeline (requirement → spec → ADR → plan → code → tests → migrations → preflight scans → verification → review → QA → readiness → PR), recommends the next action, and (with confirmation) chains the work toward "ready to ship". Detects which marketplace plugins are installed and skips inapplicable gates as N/A. | You want top-down lifecycle guidance for AI agents — orientation at the start of a session, gate enforcement before you ship. |
| **[komdosh-dev-spring-revealer](plugins/komdosh-dev-spring-revealer/)** | `/reveal <query>` (modes: survey / decision-trace / gap-find) backed by the `knowledge-revealer` agent and the `reveal-knowledge` skill. Multi-source retrieval over ADRs, specs, plans, notes, code-embedded `// DECISION:` / `// RATIONALE:` / `// NOTE:` / `// WHY:` comments, commit archaeology, and any RAG / MCP-backed knowledge bases (codebase-memory, lookstream-code-rag, Confluence/Notion/Linear, context7, ref-context). Synthesised answer with inline citations + gap list + one recommended next step. Read-only; gracefully degrades when MCP isn't configured. | You're an advanced AI user with RAG/MCP knowledge bases wired up, OR you have a non-trivial `docs/adr/` and want "have we decided this before" answered fast. |

Total: **25 agents · 19 commands · 11 mandatory skills · 12 rule documents · 2 post-edit hooks** distributed across seven plugins. Each is independently installable.

## Install in 30 seconds

Inside Claude Code:

```text
/plugin marketplace add komdosh/komdosh-claude-developer
/plugin install komdosh-dev-spring-core@komdosh-claude-developer        # always
/plugin install komdosh-dev-spring-qa@komdosh-claude-developer          # if you want QA artifacts
/plugin install komdosh-dev-spring-events@komdosh-claude-developer      # if you consume Kafka/SQS/RabbitMQ
/plugin install komdosh-dev-spring-platform@komdosh-claude-developer    # if you're auditing vendor leaks
/plugin install komdosh-dev-spring-extras@komdosh-claude-developer      # for /upgrade /detect-flakes /load-test-new
/plugin install komdosh-dev-spring-orchestrator@komdosh-claude-developer # for /lifecycle and top-down workflow guidance
/plugin install komdosh-dev-spring-revealer@komdosh-claude-developer    # for /reveal and RAG/MCP-backed knowledge retrieval
/plugin
```

The last command opens the plugin manager — verify each is **Installed** and **Enabled**.

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

Merge [`plugins/komdosh-dev-spring-core/settings.recommended.json`](plugins/komdosh-dev-spring-core/settings.recommended.json) into your consumer project's `.claude/settings.json` so agents don't get prompted for routine `./gradlew`, `git`, `docker compose`, etc. invocations.

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
| One huge plugin clutters the picker with agents you'll never use | Five focused plugins. Pick what fits your service. |
| `runBlocking` in production WebFlux, `@Transactional` on `suspend fun`, MDC across suspension | [`rules/kotlin-coroutines.md`](plugins/komdosh-dev-spring-core/rules/kotlin-coroutines.md) lists 12 forbidden patterns; `coroutine-safety-scan` skill catches them in seconds |
| Generated migrations clash with the team's checksum-based history | [`migration-writer`](plugins/komdosh-dev-spring-core/agents/migration-writer.md) emits idempotent Liquibase formatted SQL with `--changeset` headers; the `liquibase-changeset-immutability` skill catches edits to applied changesets via git history |
| New endpoints leak persistence IDs, return raw exception messages, or mix HTTP concerns into the domain | The `rules/api-conventions.md` + `rules/error-handling.md` + `rules/hexagonal.md` triad in core is loaded into every session |
| Architectural decisions get lost between Slack and code | `/adr-new` checks if an ADR is warranted, then delegates to `adr-writer` — `docs/adr/NNNN-<slug>.md` with status, alternatives, trade-offs |
| Application code gets tangled with Micrometer / jOOQ / Reactor / Jackson types directly | `komdosh-dev-spring-platform`: `/audit-leaks` finds them, then optionally extracts abstractions into a `common/` module |
| Manual QA is ad-hoc; no smoke suite for the team | `komdosh-dev-spring-qa`: three commands generate a checklist, a Newman collection, and a self-contained HTML tester from your controllers |
| One agent does everything (writes code, tests, migrations, commits) and forgets half of it | Across all plugins: 23 agents that **delegate** instead of overreach — see [anatomy of a development task](#anatomy-of-a-development-task) |

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
