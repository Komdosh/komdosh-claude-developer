<div align="center">

# komdosh-claude-developer

**An opinionated Claude Code plugin that turns Claude into a senior backend engineer for Kotlin + Spring WebFlux services.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://docs.claude.com/en/docs/claude-code)
[![Marketplace: self-hosted](https://img.shields.io/badge/Marketplace-self--hosted-2ea44f)](.claude-plugin/marketplace.json)
[![Stack: Kotlin · Spring WebFlux · coroutines](https://img.shields.io/badge/stack-Kotlin%20%C2%B7%20Spring%20WebFlux%20%C2%B7%20coroutines-orange)](rules/spring-webflux.md)

[**Install**](#install-in-30-seconds) · [**Anatomy of a task**](#spotlight-anatomy-of-a-development-task) · [**Tour**](#quick-tour) · [**Conventions**](#conventions-enforced) · [**Authoring**](#authoring-this-plugin)

</div>

---

> **19 specialised agents · 14 slash commands · 4 mandatory skills · 10 rule documents.**
> One install. Zero configuration drift across services.

## What it is

A Claude Code plugin that ships an opinionated, end-to-end workflow for **Kotlin + Spring (WebFlux + coroutines)** services. Drop it into any consumer project and Claude immediately knows your hexagonal layout, your error contract (RFC 9457), your migration style (jOOQ + Liquibase), your test conventions (Testcontainers + ArchUnit), and your observability rules (Micrometer + OpenTelemetry, no MDC in coroutine paths).

It is **not** an application or a code generator that emits boilerplate once and forgets. It is a *behavioural plugin*: each agent is narrowly scoped and delegates to siblings instead of overreaching, every skill is a checklist Claude must follow before claiming success, and every rule is loaded into the session via `CLAUDE.md` so violations are caught in the prompt — not in code review.

This repo doubles as a **self-hosted single-plugin Claude Code marketplace** — installation is a single command.

## Why

| Pain | What this plugin does about it |
|---|---|
| Claude writes `runBlocking` in production WebFlux code, drops `@Transactional` on `suspend fun`, or smuggles MDC across suspension points | [`rules/kotlin-coroutines.md`](rules/kotlin-coroutines.md) lists 12 forbidden patterns, loaded in every session |
| Generated migrations clash with the team's checksum-based history | [`migration-writer`](agents/migration-writer.md) emits idempotent Liquibase formatted SQL with `--changeset` headers, registered in the master changelog |
| New endpoints leak persistence IDs, return raw exception messages, or mix HTTP concerns into the domain | [`rules/api-conventions.md`](rules/api-conventions.md) + [`rules/error-handling.md`](rules/error-handling.md) + [`rules/hexagonal.md`](rules/hexagonal.md) — enforced from the prompt down |
| Architectural decisions get lost between Slack and code | [`/adr-new`](commands/adr-new.md) checks if an ADR is warranted, then delegates to [`adr-writer`](agents/adr-writer.md) — `docs/adr/NNNN-<slug>.md` with status, alternatives, trade-offs |
| One agent does everything (writes code, tests, migrations, commits) and forgets half of it | 19 agents that **delegate** instead of overreach — see [anatomy of a task](#spotlight-anatomy-of-a-development-task) |
| Manual QA is ad-hoc; no smoke suite for the dev or QA on the team | [`/qa-plan`](commands/qa-plan.md), [`/qa-postman`](commands/qa-postman.md), [`/qa-console`](commands/qa-console.md) generate a checklist, a Newman-runnable collection, and a self-contained HTML tester from your controllers |

## What you get

| Layer | Count | Examples |
|---|---|---|
| **Agents** | 19 | `backend-implementer`, `migration-writer`, `change-reviewer`, `service-readiness-auditor`, `integration-debugger`, `qa-plan-writer`, `qa-postman-writer`, `qa-console-writer` |
| **Slash commands** | 14 | `/add-endpoint`, `/add-migration`, `/adr-new`, `/review`, `/verify-service`, `/test-fix`, `/pr-summary`, `/qa-plan`, `/qa-postman`, `/qa-console` |
| **Skills (mandatory checklists)** | 4 | `read-service-context`, `run-verification`, `check-adr-required`, `discover-api-surface` |
| **Rules** | 10 | `hexagonal.md`, `kotlin-coroutines.md`, `spring-webflux.md`, `persistence.md`, `observability.md`, `error-handling.md`, `domain-purity.md`, `api-conventions.md`, `code-style.md`, `testing.md` |

Agents are **narrowly scoped and delegate**:
- `backend-implementer` modifies services but never bootstraps them (→ `service-bootstrapper`), never writes tests (→ `test-writer`), never writes migrations (→ `migration-writer`), never touches Gradle (→ `build-expert`).
- `cleanuper` fixes detekt/ktlint without changing behaviour. `change-reviewer` scrutinises diffs across five dimensions. `service-readiness-auditor` audits the whole service for production-readiness.
- `qa-plan-writer`/`qa-postman-writer`/`qa-console-writer` each emit one QA artifact and never modify production code.

## Spotlight: anatomy of a development task

A typical "add an endpoint" task isn't one big agent improvising — it's a chain of narrow specialists that hand off through skills. Run `/add-endpoint Order create` and this is what actually happens:

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

The same delegation pattern shows up across every command:

| Command | Orchestrates |
|---|---|
| [`/add-migration`](commands/add-migration.md) | `migration-writer` → `run-verification` |
| [`/review`](commands/review.md) | `change-reviewer` (5 dimensions; later dimensions defer if earlier ones have BLOCKERs) |
| [`/service-health`](commands/service-health.md) | `service-readiness-auditor` → fixes BLOCKERs one at a time |
| [`/test-fix`](commands/test-fix.md) | `test-writer` works through failures one class at a time |
| [`/qa-plan`](commands/qa-plan.md) / [`/qa-postman`](commands/qa-postman.md) / [`/qa-console`](commands/qa-console.md) | share `discover-api-surface` to emit a manual checklist, a Newman-runnable Postman collection, and a self-contained HTML tester |

## Install in 30 seconds

This repo ships both [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) and [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json), so a single command registers the marketplace and the plugin together.

Inside Claude Code:

```text
/plugin marketplace add komdosh/komdosh-claude-developer
/plugin install komdosh-claude-developer@komdosh-claude-developer
/plugin
```

The third command opens the plugin manager — verify the plugin is **Installed** and **Enabled**.

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

Merge [`settings.recommended.json`](settings.recommended.json) into your consumer project's `.claude/settings.json` so agents don't get prompted for routine `./gradlew`, `git`, `docker compose`, etc. invocations.

</details>

<details>
<summary><strong>Updating, disabling, removing</strong></summary>

```text
/plugin marketplace update komdosh-claude-developer    # refresh the catalogue
/plugin disable komdosh-claude-developer@komdosh-claude-developer
/plugin enable  komdosh-claude-developer@komdosh-claude-developer
/plugin uninstall komdosh-claude-developer@komdosh-claude-developer
/reload-plugins                                          # apply edits without restart
```

</details>

### Choose a scope

Claude Code asks where to install. Pick deliberately:

- **User scope** (default) — every project on your machine. `~/.claude/settings.json`.
- **Project scope** — committed to the repo. `.claude/settings.json`. Everyone who clones gets it.
- **Local scope** — only you, only this repo. `.claude/settings.local.json` (gitignored).

## Quick tour

| You want to | Run |
|---|---|
| Add a new HTTP endpoint with auth, tests, ADR check | [`/add-endpoint`](commands/add-endpoint.md) |
| Add a database migration | [`/add-migration`](commands/add-migration.md) |
| Capture an internal architectural decision | [`/adr-new`](commands/adr-new.md) |
| Review your branch before merging | [`/review`](commands/review.md) (optionally `--focus correctness,observability`) |
| Audit the whole service for production-readiness | [`/service-health`](commands/service-health.md) |
| Verify the service after a change | [`/verify-service`](commands/verify-service.md) |
| Fix failing tests one class at a time | [`/test-fix`](commands/test-fix.md) |
| Decompose a feature description into a spec | [`/analyze-requirements`](commands/analyze-requirements.md) |
| Resume an existing implementation plan | [`/continue-plan`](commands/continue-plan.md) |
| Scaffold Gatling load tests | [`/load-test-new`](commands/load-test-new.md) |
| Generate a PR/MR description | [`/pr-summary`](commands/pr-summary.md) |
| Generate a manual QA validation plan | [`/qa-plan`](commands/qa-plan.md) |
| Generate a Postman collection with assertions | [`/qa-postman`](commands/qa-postman.md) |
| Generate a self-contained HTML QA console | [`/qa-console`](commands/qa-console.md) |

## Conventions enforced

The 10 [`rules/*.md`](rules/) files are loaded into every Claude session via [`CLAUDE.md`](CLAUDE.md). Highlights:

| Rule | Notable | Enforces |
|---|---|---|
| [kotlin-coroutines.md](rules/kotlin-coroutines.md) | 12 forbidden patterns: `runBlocking` in prod/tests, `@Transactional` on `suspend fun`, `withContext` inside `@Transactional`, MDC across suspension, `Thread.sleep`, JVM blocking primitives | Coroutine safety |
| [spring-webflux.md](rules/spring-webflux.md) | Every controller handler `suspend fun`; never `Mono`/`Flux` from a controller; extract auth/correlation context **before** `withContext` | Reactive correctness |
| [hexagonal.md](rules/hexagonal.md) | Module dependency direction enforced by ArchUnit; `adapters/inbound` cannot import `adapters/outbound` | Architecture |
| [domain-purity.md](rules/domain-purity.md) | Banned imports in `domain/`/`application/`: Spring, jOOQ, Kafka, R2DBC, Jackson, JPA. `@JvmInline value class` for every domain ID | Domain isolation |
| [api-conventions.md](rules/api-conventions.md) | `/api/v<N>/<resource-plural>`, RFC 9457 `application/problem+json` errors, never expose domain entities | HTTP contract |
| [error-handling.md](rules/error-handling.md) | `ProblemDetail` everywhere; never leak stack traces/SQL/internal IDs; sealed `DomainException` hierarchy with no Spring imports | Error safety |
| [persistence.md](rules/persistence.md) | jOOQ DSL only; idempotent Liquibase formatted SQL; `TransactionalOperator.executeAndAwait` for coroutines; outbox pattern for events | Persistence safety |
| [observability.md](rules/observability.md) | Micrometer naming `<org>.<service>.<subject>.<verb>`, low-cardinality tags, OTel vendor-neutral APIs, **no MDC in WebFlux/coroutine paths** | Observability |
| [testing.md](rules/testing.md) | `runTest` (never `runBlocking`); fakes preferred over mocks (MockK only for unmockable third-party finals; never Mockito); `Clock.fixed`; Testcontainers for outbound integration tests | Test discipline |
| [code-style.md](rules/code-style.md) | `data class` + `val`, `sealed interface` for results, no `!!`, no magic numbers, ~300-line file split signal | Style |

## What this plugin assumes about your service

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

If your service doesn't look like this yet, [`/service-health`](commands/service-health.md) will tell you what's missing and offer to fix the BLOCKERs one at a time.

## Authoring this plugin

When editing the plugin itself:

| Adding a... | Place at | Required frontmatter / structure |
|---|---|---|
| Agent | `agents/<name>.md` | `name`, `model`, `description` (with concrete trigger phrases) |
| Skill | `skills/<name>/SKILL.md` | `name`, `description`; body is a numbered checklist |
| Command | `commands/<verb-noun>.md` | `# /<verb-noun>` heading; numbered orchestration steps |
| Rule | `rules/<file>.md` **and** add `@rules/<file>.md` to [`CLAUDE.md`](CLAUDE.md) | Loaded into every session |

There is no Gradle build, no test suite, and no CI. Verification is "does the prose still describe the agent's actual behaviour and the current rule references?" See [`CLAUDE.md`](CLAUDE.md) for the canonical map of how the pieces collaborate.

### Local development on the plugin itself

```bash
# Option 1: point Claude Code at your working copy
claude --plugin-dir /absolute/path/to/komdosh-claude-developer

# Option 2: symlink and reload
ln -s "$PWD" ~/.claude/plugins/komdosh-claude-developer
# inside Claude Code:
/reload-plugins
```

## Reference example

[`.example-claude/`](.example-claude/) is a snapshot of one consumer project's `.claude/` directory — it shows what richer customisation on top of this plugin looks like (additional architect agent, project-specific skills, agent memories). It is documentation only; nothing in it ships with the plugin. See [`.example-claude/README.md`](.example-claude/README.md).

## License

[MIT](LICENSE) — see the file for the full text. Use it, fork it, ship it.

---

<div align="center">

Built for backend developers who want Claude to behave like the senior on their team — not like the intern who just discovered `runBlocking`.

</div>
