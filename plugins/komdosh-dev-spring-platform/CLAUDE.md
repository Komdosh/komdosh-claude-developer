# CLAUDE.md — komdosh-dev-spring-platform

This plugin adds vendor-decoupling tooling on top of `komdosh-dev-spring-core`.

## What it adds

- Agent: [`platform-developer`](agents/platform-developer.md) — two modes:
  - **Audit mode**: scans `application/` and `domain/` for vendor-coupling leaks (Micrometer, jOOQ, Reactor, Jackson, Spring beyond stereotypes, Kafka client, R2DBC), groups by suggested abstraction, prioritises by impact, reports.
  - **Extract mode**: requires an ADR for the first-time introduction of `common/`. Then designs the interface, creates `common/<area>/<Abstraction>.kt`, the concrete adapter in `adapters/outbound/`, wires it in `boot/`, refactors all `application/` call sites, and adds an ArchUnit guard.
- Command: [`/audit-leaks`](commands/audit-leaks.md) — orchestrator. `/audit-leaks` runs audit mode; `/audit-leaks --extract <area>` runs extract mode.
- Rule: [`platform-module.md`](rules/platform-module.md) — defines the `common/` module shape, what belongs in it (and what does NOT — domain types, use cases, adapter-only DTOs), abstraction patterns for Metrics / Tx / Time / JSON / Outbox / Ids, ArchUnit guards, when to introduce the module (signals + ADR threshold).

## Dependencies

This plugin requires `komdosh-dev-spring-core` to be installed in the same project. Extract mode delegates to `adr-writer` (in core) via `/adr-new` for the first-time `common/` ADR, to `build-expert` (in core) for the new module's `build.gradle.kts`, and to `test-writer` (in core) for non-mechanical test updates. The `module-boundary-check`, `coroutine-safety-scan`, and `run-verification` skills used after extraction all live in core.

@rules/platform-module.md
