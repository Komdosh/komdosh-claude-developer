# CLAUDE.md — komdosh-dev-spring-orchestrator

This plugin adds a top-level workflow supervisor + advisor + orchestrator on top of `komdosh-dev-spring-core` (and optionally the other marketplace plugins).

## What it adds

| Item | Purpose |
|---|---|
| Command [`/lifecycle`](commands/lifecycle.md) | `/lifecycle` (= status + next-action) · `/lifecycle status` · `/lifecycle next` · `/lifecycle orchestrate` · `/lifecycle audit <gate>` |
| Command [`/recommend`](commands/recommend.md) | `/recommend [task description]` — wraps the `recommend-plugin` skill. Reads the marketplace catalog at runtime, matches the task signal against installed + known plugins, emits a primary recommendation + up to two alternates with rationale, exact invocation, and an install hint when the recommended plugin is missing. Read-only. |
| Agent [`lifecycle-supervisor`](agents/lifecycle-supervisor.md) | Three modes — Status, Advise, Orchestrate. Recommends the highest-leverage next gate to address; with confirmation, invokes the corresponding command/agent and re-evaluates. Strict safety: never auto-invokes destructive actions, never bypasses gates 8–11 (fast preflight) before running gate 12 (full verification). Capped at 5 actions per orchestrate session. |
| Skill [`lifecycle-status`](skills/lifecycle-status/SKILL.md) | Read-only. Inspects git state, working tree, doc files, and recent test results to compute a 21-gate map for the current branch (16 universal + 5 release-engineering gates that activate only when the release plugin is installed). Detects which marketplace plugins are installed and which release track applies (service vs library), emitting `N/A` for gates whose underlying capability is absent or whose track does not match. Returns a markdown table for humans + a JSON summary the supervisor parses. |
| Skill [`recommend-plugin`](skills/recommend-plugin/SKILL.md) | Read-only. Reads the current task signal from session context, matches it against the seven marketplace plugins' capabilities, detects which are installed, and emits a primary recommendation + up to two alternates with rationale and exact invocation. Triggers on "which plugin / agent / command should I use for X?" or any moment a session is uncertain which marketplace capability fits. |

## The Gate Pipeline

The 21 gates, in execution order. Earlier gates are typically cheaper — fix them first.

```text
1. Requirement captured            (text or ticket)
2. Spec written                    (docs/specs/<date>-<feature>.md, > 100 lines)
3. ADR check + write               (check-adr-required → ADR if REQUIRED)
4. Implementation plan             (docs/plans/<date>-<feature>.md)
5. Code change                     (Kotlin diff vs base)
6. Tests for change                (one test file per changed prod file)
7. Migration registered            (V*.sql in db.changelog-master.yaml)
─────  fast preflight (seconds; cheap to re-run)  ─────
8. Module-boundary scan            (skill: module-boundary-check)
9. Coroutine-safety scan           (skill: coroutine-safety-scan)
10. Liquibase immutability          (skill: liquibase-changeset-immutability)
11. jOOQ freshness                  (skill: jooq-generation-freshness)
─────  full verification + review  ─────
12. Full verification               (./gradlew :module:test → :boot:compileKotlin → detekt)
13. Code review                     (/review — change-reviewer agent)
─────  docs + readiness  ─────
14. QA artifacts fresh              (only if komdosh-dev-spring-qa installed)
15. Service readiness               (/service-health → service-readiness-auditor)
16. PR description ready            (/pr-summary)
─────  release engineering (only if komdosh-dev-spring-release installed)  ─────
17. Release readiness               (skill: verify-release-readiness-{service,library})
18. Changelog up to date            (CHANGELOG.md head section references HEAD)
19. Rollback playbook present       (service track only)
20. ABI delta reviewed              (library track only)
21. Publish config valid            (library track only)
```

A gate that does not apply to the current change (e.g., no schema change → migration gate, no qa plugin → QA-artifacts gate, no release plugin → gates 17–21, library project → gate 19, service project → gates 20+21) is reported as `N/A` rather than blocking. The `lifecycle-supervisor` agent documents this skip rule formally in its "Gate applicability" section.

## Modes

- **Status** — print the gate map and stop. Useful for orientation: "where are we?"
- **Advise** — print the map + recommend the next action with rationale. Default when invoked without subcommand. No invocation.
- **Orchestrate** — print the map, recommend the action, ask the user for confirmation, invoke it, re-evaluate, loop. Capped at 5 actions per session. Never auto-invokes destructive operations (push, merge, deploy, drop).
- **Audit** — deep-dive on a single gate: re-run its underlying skill, print full evidence, recommend a specific action.

## Dependencies

- **Required**: `komdosh-dev-spring-core` — for the foundational skills (`read-service-context`, `module-boundary-check`, `coroutine-safety-scan`, `liquibase-changeset-immutability`, `jooq-generation-freshness`, `check-adr-required`, `run-verification`) and the agents/commands that satisfy gates 2–13 + 15–16.
- **Optional**: `komdosh-dev-spring-qa` — enables gate 14. Without it, gate 14 is `N/A`.
- **Optional**: `komdosh-dev-spring-release` — enables gates 17–21. Without it, those gates are `N/A`. With it, gates 19 vs 20+21 are also conditional on the project's track (service vs library).
- **Optional**: `komdosh-dev-spring-events`, `komdosh-dev-spring-platform`, `komdosh-dev-kotlin-extras` — the supervisor will recommend their commands when relevant (e.g., `/upgrade` after a CVE flagged by readiness audit), and skip recommendations for absent ones.

The supervisor never assumes a non-core plugin is present — it detects them via the `lifecycle-status` skill's plugin-installation scan.

## Why a separate plugin

Lifecycle supervision is a meta-workflow concern — it orchestrates the other plugins rather than implementing application code. Some teams prefer to compose workflows manually and don't want top-down guidance; others rely on it heavily. Separating it as an opt-in plugin honours both.
