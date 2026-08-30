# komdosh-dev-spring-core

Foundation for Kotlin + Spring (WebFlux + coroutines) services: writing, verifying, and reviewing code inside one service — including its event consumers and Avro schemas, which are bound to the same hexagonal and coroutine rules.

Siblings: `spring-quality` (audits, QA artifacts) · `spring-delivery` (lifecycle, planning, release) · `revealer` (`/reveal`, `/doc-reveal`) · `kotlin-extras` (`/upgrade`, `/detect-flakes`, `/load-test-new`) · `infra-*` (Terraform/YC, Kubernetes/ArgoCD).

## Agent routing

- `backend-implementer` — behaviour changes. Writes **no** tests (→ `test-writer`) and **no** migrations (→ `/add-migration`).
- `test-writer` — unit, Testcontainers integration, ArchUnit. Never touches production code.
- `service-bootstrapper` — a new service's leaf-module skeleton, one shot.
- `event-consumer-author` / `avro-schema-author` — consumers and the schemas upstream of them.
- `cleanuper` — bulk detekt/ktlint fixes, one violation at a time, never a behaviour change.
- `integration-debugger` — failures that aren't plain compile errors. Checks coroutine causes first.
- `code-reviewer` — read-only; `scope=diff` reviews a change, `scope=service` audits production readiness.

Config, Gradle, observability, security-filter, and container work has **no agent** — it is reference knowledge, so it lives in the rules and is applied inline where the work happens. A subagent hop there costs more context than it saves.

**Kubernetes, Helm, ArgoCD, and CI are not this plugin's job** — `komdosh-dev-infra-k8s`/`-core` own the hardening rules, and a manifest written from here is one they correctly reject.

## Skills are mandatory, not optional

| Skill | When |
|---|---|
| `read-service-context` | Once per session. Emits `kind: service \| library` — the marketplace's single track-detection point |
| `run-verification` | After **any** code change, before reporting done. Narrowest-first (`:<module>:test` → `:boot:compileKotlin` → detekt); never `./gradlew build` when a narrower target works |
| `coroutine-safety-scan` · `module-boundary-check` · `pii-safety-scan` | On touched files, before declaring done — seconds each, and they catch what would otherwise cost a full verification cycle |
| `liquibase-changeset-immutability` · `jooq-generation-freshness` | After touching `V*.sql` — they turn a next-deploy boot failure and a "method does not exist on Record" loop into local findings |
| `pre-edit-impact-check` | Before a rename or removal that may have call sites |
| `check-adr-required` | REQUIRED iff hard-to-reverse ∧ ≥2 reasonable alternatives ∧ within the service boundary |
| `discover-avro-toolchain` · `verify-schema-compat` | Before a schema ships |

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
