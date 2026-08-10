# CLAUDE.md — komdosh-dev-spring-core

Guidance for Claude Code when this plugin is active. Loaded automatically when `komdosh-dev-spring-core` is installed.

## What this plugin is

The **must-have foundation** for Kotlin + Spring (WebFlux + coroutines) backend services: everything needed to write, verify, and review code inside one service — including its event consumers and Avro schemas, because those are implementation concerns bound to the same hexagonal and coroutine rules.

Companion plugins layer on top:

| Plugin | Adds |
|---|---|
| `komdosh-dev-spring-quality` | Security/PII audits, vendor-leak audit, QA artifacts (`/qa`, `/security-audit`, `/audit-leaks`) |
| `komdosh-dev-spring-delivery` | Lifecycle gates, Jira entry, architecture-driven planning, release engineering |
| `komdosh-dev-revealer` | `/reveal` (project knowledge) and `/doc-reveal` (source docs) |
| `komdosh-dev-kotlin-extras` | `/upgrade`, `/detect-flakes`, `/load-test-new` |
| `komdosh-dev-infra-*` | Terraform/Yandex, Kubernetes/ArgoCD, and the shared infra safety discipline |

This is a *behavioural* plugin — no application source, no Gradle build, no test suite. "Build/lint/test" means editing Markdown/JSON content and running `tools/lint-marketplace.sh` from the repo root.

## Plugin layout

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `agents/*.md` | 8 subagents |
| `commands/*.md` | 13 slash commands |
| `skills/<name>/SKILL.md` | 11 skills (mandatory checklists, tracked as todos when invoked) |
| `rules/*.md` | 19 convention documents, loaded via the `@rules/...` imports below |
| `hooks/` | 2 hooks (`session-context.sh` on SessionStart, `migration-register-reminder.sh` on PostToolUse) |
| `settings.recommended.json` | Suggested `permissions.allow`/`deny` to merge into a consumer project's `.claude/settings.json` |

## Big picture

The plugin assumes a hexagonal Kotlin service (`rules/hexagonal.md`):

```
domain/  ←  application/  ←  adapters/{inbound,outbound}  ←  boot/
                                                            └  load-tests/
```

`domain/` has zero framework imports. `application/` orchestrates use cases through ports it defines. Adapters implement ports. `boot/` is the only composition root.

### What is an agent, and what is a rule

An **agent** earns its place when the work is bulk, isolatable, or needs a different reasoning mode — otherwise the subagent hop costs more context than it saves, because the subagent doesn't have the conversation. Reference knowledge ("how do I write a filter chain", "how do I add a dependency") is a **rule**, not an agent: it belongs in context where the work happens.

The eight agents:

- `backend-implementer` — the workhorse for behaviour changes inside one service. Does **not** write tests (→ `test-writer`) or migrations (→ `/add-migration`).
- `test-writer` — unit, integration (Testcontainers), and ArchUnit tests. Never changes production code.
- `service-bootstrapper` — creates a new service's leaf-module skeleton. One large one-shot artifact.
- `event-consumer-author` — Kafka/SQS/RabbitMQ consumers per `rules/event-consumers.md`.
- `avro-schema-author` — Avro schemas and the generated event-DTO pipeline. Sits upstream of the consumer author.
- `cleanuper` — bulk detekt/ktlint fixes, one violation at a time, never a behaviour change. Cheap model, genuinely isolatable.
- `integration-debugger` — root-cause diagnosis of failures that aren't obviously compile errors. Checks coroutine causes first.
- `code-reviewer` — read-only. `scope=diff` reviews a change across five dimensions; `scope=service` audits the whole service for production readiness. One agent, because the checklists overlap almost entirely and only the scope differs.

Config, Gradle, observability, security-filter, and container knowledge live in `rules/configuration.md`, `rules/gradle-build.md`, `rules/observability.md`, `rules/spring-security.md`, and `rules/local-dev.md` — read them and apply them inline.

**Kubernetes manifests, Helm, ArgoCD, and CI pipelines are not this plugin's job.** They belong to `komdosh-dev-infra-k8s` / `komdosh-dev-infra-core`, which own the hardening rules; a deployment manifest written from here would be one those plugins correctly reject.

### Skills are mandatory checklists, not suggestions

- `read-service-context` — orients to a consumer service (`service.yaml`, else `docs/README.md` + discovery). Emits `kind: service | library` — the marketplace's single track-detection point. Run **once per session**.
- `run-verification` — narrowest-first Gradle verification (`:<module>:test` → `:boot:compileKotlin` → `:<module>:detekt`). Required after any code change before reporting done. Never `./gradlew build` when a narrower target works.
- `coroutine-safety-scan` — greps the 12 forbidden patterns from `rules/kotlin-coroutines.md` on touched files. Seconds, and it catches what would otherwise cost a full verification cycle.
- `pii-safety-scan` — the single Kotlin-side personal-data scan, at `depth=fast` (dev loop) or `depth=audit` (classified report). Never prints a value.
- `module-boundary-check` — greps imports against the hexagonal arrows. Faster preflight than ArchUnit; the ArchUnit suite stays the source of truth.
- `liquibase-changeset-immutability` — detects any `V*.sql` modified after first commit, i.e. the next deploy's checksum-mismatch boot failure, locally.
- `jooq-generation-freshness` — flags generated jOOQ classes stale relative to the newest changeset. Kills "method does not exist on Record" loops.
- `pre-edit-impact-check` — lists every call site before a rename/removal, so an edit doesn't silently break N of them.
- `check-adr-required` — REQUIRED iff (hard to reverse) ∧ (≥2 reasonable alternatives) ∧ (within service boundary).
- `discover-avro-toolchain` / `verify-schema-compat` — which Avro plugin and registry are present; BACKWARD/FORWARD/FULL/BREAKING verdict before a schema ships.

### Hooks

Both emit the Claude Code JSON output protocol (`hookSpecificOutput.additionalContext`) — the only exit-0 channel the model actually sees.

- `session-context.sh` — `SessionStart`. Injects `service.yaml`'s head plus the preflight-skill map, so the session starts oriented without spending a `read-service-context` call. Silent no-op in non-service repos.
- `migration-register-reminder.sh` — `PostToolUse` on a write to `db/changelog/V*__*.sql`. If it isn't referenced in `db.changelog-master.yaml` yet, returns the `include:` snippet.

## Conventions imported as rules

Read each file in full when its concern is in scope. Highlights:

- **`kotlin-coroutines.md`** — the 12 forbidden patterns: `runBlocking` in production or tests, `@Transactional` on `suspend fun`, `withContext` inside `@Transactional`, extracting security/trace context inside `withContext`, JVM blocking primitives across suspension, `Thread.sleep`.
- **`spring-webflux.md`** — every handler is a `suspend fun`; never return `Mono`/`Flux` from a controller; no business logic in controllers; extract auth/correlation context **before** `withContext`.
- **`hexagonal.md`** / **`domain-purity.md`** — the ArchUnit-enforced dependency arrows; banned imports in `domain/`/`application/`; `@JvmInline value class` for every domain ID.
- **`api-conventions.md`** / **`error-handling.md`** — `/api/v<N>/<resource-plural>`; RFC 9457 `application/problem+json` everywhere; never leak stack traces, SQL, or persistence IDs; sealed `DomainException` with no Spring imports.
- **`code-style.md`** — `data class` + `val`, `sealed interface` for results, no `!!`, no magic numbers.
- **`testing.md`** — `runTest` never `runBlocking`; fakes over mocks (MockK only for unmockable third-party finals, never Mockito); `Clock.fixed`; Testcontainers with real Postgres for outbound adapters; `@WebFluxTest` for controllers.
- **`persistence.md`** — jOOQ DSL only; idempotent Liquibase changesets registered in the master changelog; `TransactionalOperator.executeAndAwait`; outbox pattern for events; jOOQ `Record` never escapes `adapters/outbound/`.
- **`observability.md`** — Micrometer `<org>.<service>.<subject>.<verb>`, low-cardinality tags only; OTel vendor-neutral APIs; **no MDC in WebFlux/coroutine paths**; the `Timer.recordSuspending` pattern for timing a `suspend fun`.
- **`pii-handling.md`** — classify PII at the type level with redacting `toString()`; never log/trace/tag raw PII; minimise, mask at the boundary, tokenise downstream; PII in events is a documented decision; build erasure/access/retention in from day one (GDPR Art. 15/17/20, 152-FZ). Storage and residency obligations are infra-core's `rules/pii-data-protection.md`.
- **`event-consumers.md`** — manual offset/ack, mandatory idempotency via `processed_events`, transient-vs-poison error policy, DLQ routing, schema-registry DTOs, Testcontainers tests, 8 forbidden patterns.
- **`avro-schemas.md`** / **`avro-codegen.md`** / **`avro-registry.md`** — T-first nullable unions, required `doc` fields, decimal/uuid/timestamp-millis logical types, aliases on rename; the davidmc24 default with Confluent/avro4k detection; BACKWARD compatibility, `auto.register.schemas=false` in prod, no inlined registry credentials.
- **`gradle-build.md`** — the version catalog is the only place versions live; `implementation` over `api`; convention plugins over copy-paste; never invent a version.
- **`configuration.md`** — every value externalised with a default; feature switches default off; typed `@ConfigurationProperties` over `@Value`; no secret literal in any committed YAML.
- **`spring-security.md`** — extract the principal before any dispatcher switch; 401 vs 403 semantics, both as `problem+json`; `anyExchange().authenticated()` always last; every auth change ships with a deny-case test.
- **`local-dev.md`** — Compose runs dependencies (with healthchecks and pinned tags), not the service; multi-stage Dockerfile with a non-root UID so the runtime's `runAsNonRoot` is satisfiable; never `COPY` a secret into a layer.

## When editing this plugin

- New agent → `agents/<name>.md` with frontmatter `name`, `model` (alias only), and a `description` containing concrete trigger phrases. Ask first whether it should be a rule instead.
- New skill → `skills/<name>/SKILL.md` with `name` + `description` and a numbered checklist.
- New command → `commands/<verb-noun>.md`.
- New rule → add the file **and** its `@rules/<file>.md` import below, or it is never loaded.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

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
@rules/event-consumers.md
@rules/avro-schemas.md
@rules/avro-codegen.md
@rules/avro-registry.md
@rules/gradle-build.md
@rules/configuration.md
@rules/spring-security.md
@rules/local-dev.md
