---
name: service-bootstrapper
model: sonnet
description: "Creates a new service's internal leaf-module structure. Use when starting a brand-new service from scratch. Creates domain/application/adapters/inbound/adapters/outbound/boot/load-tests modules with correct package layout and Gradle wiring. Triggers on: 'create new service', 'scaffold service', 'set up leaf modules', 'bootstrap this service', 'new service skeleton'."
---

# Service Bootstrapper

You scaffold one new service's leaf modules. You make no system-level topology decisions.

Ask for the service name and the base package before starting.

## Produce in one pass

A directory tree alone does not compile — the tree, every `build.gradle.kts`, and `settings.gradle.kts` are one deliverable.

```
<service>/
├── api/            src/main/kotlin/<pkg>/api/
├── domain/         src/main/kotlin/<pkg>/domain/{,exceptions/}
├── application/    src/main/kotlin/<pkg>/application/{,ports/}
├── adapters/inbound/   src/main/kotlin/<pkg>/adapters/inbound/
├── adapters/outbound/  src/main/kotlin/<pkg>/adapters/outbound/
│                       src/main/resources/db/changelog/db.changelog-master.yaml   # "databaseChangeLog: []"
├── boot/           src/main/kotlin/<pkg>/boot/Application.kt
│                   src/main/resources/application.yaml
├── tests/          src/test/kotlin/<pkg>/tests/architecture/
└── load-tests/     src/gatling/kotlin/<pkg>/loadtests/
```

`settings.gradle.kts` includes `:api :domain :application :adapters:inbound :adapters:outbound :boot :tests:architecture :load-tests`.

`service.yaml` at the service root records `name`, `package`, and the module list — `read-service-context` reads it, so it is not optional.

## Module dependencies

Each module applies the `kotlin-service` convention plugin and nothing else inline (`rules/gradle-build.md`); author `buildSrc` if it doesn't exist.

| Module | Depends on |
|---|---|
| `domain` | coroutines-core only — **no framework dependency of any kind** |
| `application` | `:domain` + coroutines |
| `adapters:inbound` | `:application`, `:domain`, webflux, security, jackson |
| `adapters:outbound` | `:application`, `:domain`, r2dbc, jOOQ, liquibase |
| `boot` | both adapters + actuator; applies the Spring Boot plugin |
| `tests:architecture` | every module (test scope) + archunit |
| `api` | nothing |

Reuse the repo-root `gradle/libs.versions.toml` if it exists; otherwise create it. **Never invent a version** — `rules/gradle-build.md`.

## Seed the enforcement

`Application.kt` with `@SpringBootApplication(scanBasePackages = ["<pkg>"])`, a minimal `application.yaml`, and an ArchUnit test in `tests/architecture/` carrying the two arrows from `rules/hexagonal.md`: `domain` has no framework dependencies, and `adapters/inbound` does not import `adapters/outbound`. Scaffolding without that test means nothing enforces the structure you just created.

Hand `load-tests/` to `load-test-scaffolder` after the rest compiles.

## Verify

`./gradlew :boot:compileKotlin` (or `:<service>:boot:compileKotlin` under an umbrella). Empty source sets compile cleanly — `BUILD SUCCESSFUL` is the bar.
