# CLAUDE.md — komdosh-dev-spring-core

This file provides guidance to Claude Code (claude.ai/code) when this plugin is active. It is loaded automatically when `komdosh-dev-spring-core` is installed.

## What this plugin is

`komdosh-dev-spring-core` is the **must-have foundation** for Kotlin + Spring (WebFlux + coroutines) backend services. It packages the agents, slash commands, skills, rules, and one hook that every consumer service needs.

Companion plugins ship in the same marketplace and add scoped capabilities on top of this core. Install whichever you need:

| Plugin | Adds |
|---|---|
| `komdosh-dev-spring-events` | Kafka/SQS/RabbitMQ consumer authoring + `rules/event-consumers.md` |
| `komdosh-dev-spring-qa` | `/qa-plan` `/qa-postman` `/qa-console`, the `discover-api-surface` skill |
| `komdosh-dev-spring-platform` | `/audit-leaks` + `platform-developer` agent + `rules/platform-module.md` |
| `komdosh-dev-kotlin-extras` | `dependency-upgrader` (`/upgrade`), `flaky-test-detector` (`/detect-flakes`), `load-test-scaffolder` (`/load-test-new`) |

This is a *behavioural* plugin — there is no application source code here, no Gradle build, no test suite. "Build/lint/test" means editing the plugin's Markdown/JSON content, not compiling code.

## Plugin layout

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `agents/*.md` | 15 specialized subagents (each with `name` + `description` + trigger phrases in frontmatter) |
| `commands/*.md` | 10 slash commands (`/add-endpoint`, `/add-migration`, `/adr-new`, `/review`, `/verify-service`, `/test-fix`, `/pr-summary`, `/service-health`, `/analyze-requirements`, `/continue-plan`) |
| `skills/<name>/SKILL.md` | 9 skills (mandatory checklists, tracked as todos when invoked) |
| `rules/*.md` | 11 convention documents loaded via `@rules/...` imports below |
| `hooks/` | 2 hooks (`session-context.sh` on SessionStart, `migration-register-reminder.sh` on PostToolUse) auto-installed via `hooks/hooks.json` |
| `settings.recommended.json` | Suggested `permissions.allow`/`deny` for consumer projects to merge into `.claude/settings.json` |

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

Skills are mandatory checklists, not suggestions:
- `read-service-context` — orients an agent to a consumer service (reads `service.yaml` or falls back to `docs/README.md` + filesystem discovery). Run **once per session**, not repeatedly.
- `run-verification` — narrowest-first Gradle verification (`:<module>:test` → `:boot:compileKotlin` → `:<module>:detekt`). Required after any code change before reporting done. Never run `./gradlew build` when a narrower target works.
- `check-adr-required` — REQUIRED iff (hard to reverse) ∧ (≥2 reasonable alternatives) ∧ (within service boundary).
- `pre-edit-impact-check` — before renaming/removing a class, function, DTO field, or port-interface method, lists every direct and indirect call site with its module so the edit doesn't break N sites silently. Recommends in-place rename / deprecate-then-remove / dual-publish based on scale and reach.
- `coroutine-safety-scan` — grep-based scan for the 12 forbidden patterns from `rules/kotlin-coroutines.md` on touched files. Runs in seconds; catches `runBlocking` / `Thread.sleep` / `@Transactional` on suspend / MDC-across-suspension before `run-verification` runs.
- `pii-safety-scan` — grep-based scan for the personal-data violations from `rules/pii-handling.md` on touched files: raw PII interpolated into log/trace statements, PII value classes without a redacting `toString()`, PII in event payloads / DTO responses without masking, PII in span/metric tags. Runs in seconds; never prints the value. Run alongside `coroutine-safety-scan` before reporting a change done.
- `module-boundary-check` — grep imports against the hexagonal arrows from `rules/hexagonal.md` and the banned imports from `rules/domain-purity.md`. Faster preflight than full ArchUnit; the ArchUnit suite under `tests/architecture/` remains the source of truth.
- `liquibase-changeset-immutability` — uses git history to detect any `V*.sql` modified after first commit. Catches the next deploy's checksum-mismatch failure locally; tolerates whitespace-only and rollback-only edits.
- `jooq-generation-freshness` — compares mtime of `*/build/generated/sources/jooq/` against the newest `V*.sql` to flag stale generated classes. Saves "method does not exist on Record" loops after a migration.

Hooks (auto-installed via `hooks/hooks.json`; both emit the Claude Code JSON output protocol — `hookSpecificOutput.additionalContext` — so the hint actually reaches the model):
- `session-context.sh` — fires `SessionStart` (startup/resume/clear). If the project has a `service.yaml`, injects its head plus the mandatory preflight-skill map as additionalContext — the session starts oriented without spending a `read-service-context` invocation. Silent no-op in non-service repos.
- `migration-register-reminder.sh` — fires `PostToolUse` on write of `db/changelog/V*__*.sql`. If the file is not yet referenced in `db.changelog-master.yaml`, returns the `include:` snippet to add.

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
- **`pii-handling.md`** — application-layer personal-data discipline: classify PII at the type level (value classes with a redacting `toString()`, `@Pii` markers); never log/trace/tag raw PII (log surrogate IDs); minimise, mask at the API boundary, tokenise for downstream; field-level encryption + crypto-shred for special categories; PII in events is a documented, controlled decision; build erasure/access/retention in from day one (GDPR Art. 15/17/20, 152-FZ). When the infra suite is present, storage/residency obligations live in infra-core's `rules/pii-data-protection.md`.

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
@rules/pii-handling.md

Never put a Co-Authored into commits
