# Changelog

All notable changes to this marketplace. Format follows [Keep a Changelog](https://keepachangelog.com/); the marketplace `version` in `.claude-plugin/marketplace.json` tracks the wave, individual plugins version independently.

## [0.3.0] — 2026-06-10

First-class plugin engineering wave. Every plugin bumped one minor (0.1.0 → 0.2.0, 0.2.0 → 0.3.0).

### Added
- **New plugin: `komdosh-dev-arch-planner` (0.1.0)** — `/implementation-plan <service>` creates a whole-service implementation agentic plan from the company architecture repository. Ships the `implementation-planner` agent (opus), the internal `discover-architecture-context` skill (arch-repo resolution ladder with code-RAG MCP degraded mode, tiered evidence inventory T0–T7, gap reporting), and `rules/agentic-plan.md` (executor mapping onto marketplace agents/commands + frozen fallback plan contract). Defers to the architecture repo's own `plan-service-implementation` contract when present; plans land in `docs/plans/` where core's `/continue-plan` resumes.
- `dependencies` in every companion plugin's `plugin.json` — installing any plugin now auto-installs `komdosh-dev-spring-core` at the same scope; `komdosh-dev-tasker` additionally pulls `komdosh-dev-spring-orchestrator`.
- `category` + `tags` on every `marketplace.json` entry, marketplace-level `description`/`version`, and `metadata.pluginRoot` for terse sources.
- **core**: `session-context.sh` SessionStart hook — when the project has a `service.yaml`, injects the service summary and the mandatory preflight-skill map as `additionalContext` before the first prompt. Runs once per session, millisecond-scale, silent no-op elsewhere.
- `disallowedTools` on the read-only agents (`change-reviewer`, `service-readiness-auditor`, `security-auditor`, `knowledge-revealer`, `doc-revealer`) — "read-only" is now enforced at the tool layer.
- `skills:` preloading on 11 specialist agents (e.g. `backend-implementer` → `coroutine-safety-scan` + `module-boundary-check`; `security-auditor` → all three audit skills) — no discovery round-trips.
- `user-invocable: false` on the 18 internal skills, keeping the `/` menu down to what users should actually type.
- `allowed-tools` on the read-only core scan skills (`Grep, Glob, Read`, plus scoped `Bash(git …:*)`/`Bash(find:*)` where needed) — preflight scans no longer permission-prompt.
- Lint check families 10–15 in `tools/lint-marketplace.sh`: plugin.json completeness + dependency resolution, marketplace category/tags, agent model-alias enforcement, hooks.json hygiene (`${CLAUDE_PLUGIN_ROOT}` + timeout), frontmatter description budget (1536-char listing cap), and hook JSON-protocol compliance.

### Removed
- **Hook policy: only millisecond-scale, high-value hooks survive.** Dropped `qa-staleness-warn.sh` (fired on every Edit/Write; staleness is already surfaced by core's `service-readiness-auditor`) and `pre-tag-validation.sh` (fired on every Bash call; the pre-tag discipline is owned by `release-coordinator` and `rules/release-engineering.md`). The marketplace now ships exactly two hooks, both in core: the once-per-session `session-context.sh` and the migration-register reminder, which exits immediately unless the edited file is a `db/changelog/V*.sql`. No per-Bash-call hooks, no test-running hooks, nothing long-running.

### Fixed
- **The surviving migration-register hook emitted its hint to stderr with exit 0 — a channel the model never sees on PostToolUse.** It now emits the Claude Code JSON output protocol (`hookSpecificOutput.additionalContext`) on stdout, so the Liquibase-registration reminder actually reaches the model.

### Changed
- The two remaining hooks declare explicit `timeout` and `statusMessage`.
