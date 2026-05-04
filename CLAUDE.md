# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`komdosh-claude-developer` is a **Claude Code plugin** (manifest: `.claude-plugin/plugin.json`) — not an application. It packages agents, slash commands, skills, and rule documents that enforce conventions for **Kotlin + Spring (WebFlux + coroutines)** backend services in *consumer* projects that install this plugin.

There is no application source code, no Gradle build, and no test suite in this repo. "Build/lint/test" commands here mean editing the plugin's Markdown/JSON content, not compiling code.

## Repository layout

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest (name, version, keywords) |
| `agents/*.md` | 16 specialized subagents (each with `name` + `description` + trigger phrases in frontmatter) |
| `commands/*.md` | Slash commands (e.g. `/add-endpoint`, `/add-migration`, `/review`, `/verify-service`) |
| `skills/<name>/SKILL.md` | Skills with explicit step checklists: `read-service-context`, `run-verification`, `check-adr-required` |
| `rules/*.md` | Convention documents loaded by `CLAUDE.md` via `@rules/...` imports |
| `settings.recommended.json` | Suggested `permissions.allow`/`deny` block for consumer projects to merge into `.claude/settings.json` |
| `.example-claude/` | **Local reference only** (gitignored). Snapshot of one consumer project's `.claude/` directory — illustrative, not shipped. Do not edit as if it were the plugin's own settings. |

## Big picture: how the pieces collaborate

The plugin assumes a hexagonal Kotlin service with this leaf-module shape (enforced in `rules/hexagonal.md`):

```
domain/  ←  application/  ←  adapters/{inbound,outbound}  ←  boot/
                                                            └  load-tests/
```

`domain/` has zero framework imports. `application/` orchestrates use cases through ports it defines. Adapters implement ports. `boot/` is the only composition root.

Agents are scoped to one concern each and **delegate** rather than overreach:
- `service-bootstrapper` creates skeletons; `backend-implementer` modifies existing services and never bootstraps.
- `backend-implementer` does **not** write tests (→ `test-writer`) and does **not** write migrations (→ `migration-writer`).
- `build-expert` owns Gradle/`libs.versions.toml`; `infra-expert` owns Docker/k8s/CI; `config-expert` owns `application.yaml` and Spring profiles. None of these touch business logic.
- `cleanuper` fixes detekt/ktlint without changing behavior. `change-reviewer` reviews diffs across five dimensions; `service-readiness-auditor` audits the whole service.
- `adr-writer` is invoked when `check-adr-required` skill returns REQUIRED/BORDERLINE — a within-service architectural decision must be captured in `docs/adr/NNNN-<slug>.md` *before* implementation.
- `qa-plan-writer`, `qa-postman-writer`, and `qa-console-writer` each generate one QA artifact under `docs/qa/`. They share the `discover-api-surface` skill (OpenAPI file → Springdoc runtime if hinted → static controller parse) and never modify production code. Triggered by `/qa-plan`, `/qa-postman`, and `/qa-console` respectively. The `service-readiness-auditor` warns when these artifacts are missing or stale relative to controller mtimes (warn-level only — never a BLOCKER).

Skills are mandatory checklists, not suggestions:
- `read-service-context` — orients an agent to a consumer service (reads `service.yaml` or falls back to `docs/README.md` + filesystem discovery). Run **once per session**, not repeatedly.
- `run-verification` — narrowest-first Gradle verification (`:<module>:test` → `:boot:compileKotlin` → `:<module>:detekt`). Required after any code change before reporting done. Never run `./gradlew build` when a narrower target works.
- `check-adr-required` — REQUIRED iff (hard to reverse) ∧ (≥2 reasonable alternatives) ∧ (within service boundary).
- `discover-api-surface` — resolves the service's HTTP surface into a normalised JSON IR for the QA artifact writers. Tries OpenAPI file, then Springdoc runtime if hinted, then static controller parse. Run **once per session** when generating multiple QA artifacts back-to-back.

## Conventions imported as rules

The 10 `rules/*.md` files below are loaded via `@rules/...` imports and apply to any Kotlin code generated for consumer services. Read each file in full when its concern is in scope; the highlights:

- **`kotlin-coroutines.md`** — 12 forbidden patterns, including `runBlocking` in production/tests, `@Transactional` on `suspend fun`, `withContext` inside `@Transactional`, extracting security/trace context inside `withContext`, JVM blocking primitives across suspension points, `Thread.sleep`. All enforced conceptually.
- **`spring-webflux.md`** — every controller handler must be `suspend fun`; never return `Mono`/`Flux` from a controller; no business logic in controllers; extract auth/correlation context **before** `withContext`.
- **`hexagonal.md`** — module dependency direction enforced by ArchUnit. `adapters/inbound` must not import from `adapters/outbound`. Domain has no framework deps.
- **`domain-purity.md`** — banned imports in `domain/`/`application/` (Spring, jOOQ, Kafka, R2DBC, Jackson, Jakarta Persistence). `@JvmInline value class` for every domain ID.
- **`api-conventions.md`** — `/api/v<N>/<resource-plural>`, RFC 9457 `application/problem+json` for errors, never expose domain entities or persistence IDs.
- **`error-handling.md`** — `ProblemDetail` everywhere; never leak stack traces/SQL/internal IDs; sealed `DomainException` hierarchy with no Spring imports.
- **`code-style.md`** — `data class` + `val`, `sealed interface` for results, no `!!`, no magic numbers (~300-line file split signal).
- **`testing.md`** — `runTest` (never `runBlocking`); fakes preferred over mocks (MockK only for unmockable third-party finals; never Mockito); `Clock.fixed` for time; Testcontainers for integration tests (real Postgres, not H2 for outbound adapters); `@WebFluxTest` + `@MockkBean` for controllers.
- **`persistence.md`** — jOOQ DSL only (no raw SQL); idempotent Liquibase changesets `V<N>__<verb>-<thing>.sql` registered in master changelog; `TransactionalOperator.executeAndAwait` for coroutine transactions; outbox pattern for events; jOOQ `Record` types must not escape `adapters/outbound/`.
- **`observability.md`** — Micrometer naming `<org>.<service>.<subject>.<verb>`, low-cardinality tags only; OTel vendor-neutral APIs only; **no MDC in WebFlux/coroutine paths** (ThreadLocal-unsafe across suspension); pass log context as explicit fields.

## When editing this plugin

- Adding a new agent: place `agents/<name>.md` with frontmatter `name`, `model`, and a `description` containing concrete trigger phrases. Keep scope narrow and call out which other agents it must escalate to.
- Adding a new skill: place `skills/<name>/SKILL.md` with frontmatter `name` + `description` and a numbered checklist (these are tracked as todos when invoked).
- Adding a new command: `commands/<verb-noun>.md`.
- Editing rules: rules are imported by `CLAUDE.md` via `@rules/...`. Adding a new rule file requires adding the corresponding `@rules/<file>.md` line to `CLAUDE.md` so it is loaded.
- The plugin itself is consumed in other repos — there is nothing to build or test here. Verification is "does the prose still describe the agent's actual behavior and current rule references."

@rules/kotlin-coroutines.md
@rules/spring-webflux.md
@rules/api-conventions.md
@rules/hexagonal.md
@rules/domain-purity.md
@rules/error-handling.md
@rules/code-style.md
@rules/testing.md
@rules/persistence.md
@rules/observability.md

Never put a Co-Authored into commits
