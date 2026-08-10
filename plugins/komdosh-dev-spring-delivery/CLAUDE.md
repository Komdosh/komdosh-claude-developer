# CLAUDE.md — komdosh-dev-spring-delivery

Everything between "a ticket exists" and "the release PR is open", on top of `komdosh-dev-spring-core`. Four phases of one pipeline: **enter work → plan it → track it to done → ship it.**

## What it adds

### Entry — where work comes from

| Command | Backed by | What it does |
|---|---|---|
| [`/jira-task [PROJ\|PROJ-123]`](commands/jira-task.md) | [`discover-jira-task`](skills/discover-jira-task/SKILL.md) | Pulls one ticket from the project's Todo column via the Atlassian MCP, applies the first forward workflow transition, hands the description to the supervisor as the captured requirement, and on a clean gate map applies the next forward transition. Forward-only walk — never hardcodes status names. Refuses without an Atlassian MCP; no manual-paste fallback. |
| [`/implementation-plan <service>`](commands/implementation-plan.md) | [`discover-architecture-context`](skills/discover-architecture-context/SKILL.md) → [`implementation-planner`](agents/implementation-planner.md) | Resolves the company architecture repository, locates the service's architecture package, assembles a tiered evidence inventory (entry contracts → service package → domain → system → ADR constraints → business scope → dev-ex standards), probes current implementation state, and writes `docs/plans/<date>-<service>-implementation-plan.md` — ordered todos with priority, inputs, write scope, acceptance criteria, verification, dependencies, and the executor for each. Read-only on the architecture repo. |

For a spec from free text rather than an architecture repo, use core's `/analyze-requirements`.

### Orchestration — what to do next

| Command | Backed by | What it does |
|---|---|---|
| [`/lifecycle [status\|next\|orchestrate\|audit]`](commands/lifecycle.md) | [`lifecycle-status`](skills/lifecycle-status/SKILL.md) → [`lifecycle-supervisor`](agents/lifecycle-supervisor.md) | Computes the gate map from **real git state** (branch, merge base, changed files, doc mtimes, scan results), marks each gate MET / PENDING / N/A / UNKNOWN with its evidence, recommends the single highest-leverage next action, and — with explicit confirmation — chains work toward "ready to ship". |
| [`/recommend [task]`](commands/recommend.md) | [`recommend-plugin`](skills/recommend-plugin/SKILL.md) | Points a session at the right marketplace capability for a task, reading the catalog at runtime from `marketplace.json` + each installed `plugin.json`. |

**The installed-plugin set is discovered, never hardcoded.** A fixed list goes stale the moment the marketplace ships a plugin, and every gate belonging to an unlisted plugin then vanishes from the map silently — which is exactly what happened before. An undetectable plugin yields UNKNOWN, not MET.

### Release — two tracks, one plugin

Track detection order: `service.yaml`'s `kind` field → core's `read-service-context` heuristics → `--track=` override. Ambiguity stops and asks once.

**Both tracks**: [`/release-prep`](commands/release-prep.md) (composite readiness gate, stops on any FAIL with per-gate remediation) · [`/changelog`](commands/changelog.md) (Conventional Commits → Keep-a-Changelog section) · [`/version-bump`](commands/version-bump.md) · [`/release-notes`](commands/release-notes.md).

**Service track** adds [`/rollback-playbook`](commands/rollback-playbook.md) — per migration in the release window, inverse SQL where mechanically reversible, an explicit "forward-fix only" with rationale otherwise, plus the ENV vars and feature flags that must move atomically with the rollback.

**Library track** adds [`/abi-check`](commands/abi-check.md) (public API surface vs the last released tag, per-symbol added/deprecated/changed-signature/removed) · [`/publish-prep`](commands/publish-prep.md) (POM completeness, signing, credentials reachability, no `-SNAPSHOT` deps — read-only) · [`/deprecate-api`](commands/deprecate-api.md). On this track the version bump is **ABI-load-bearing**: a breaking ABI delta forces major regardless of commit prefixes.

Agents: [`release-coordinator`](agents/release-coordinator.md) drives the pipeline and opens the PR; [`library-publisher`](agents/library-publisher.md) owns the publish step and `/deprecate-api`. The changelog section is written by the [`write-changelog`](skills/write-changelog/SKILL.md) skill, inline — it is a deterministic git-log-to-markdown transform, so running it as an agent was a nested subagent hop that bought no isolation. The coordinator and the publisher stay separate on purpose — one is bound by "never deploys, never publishes" and stops at *PR open*; the other performs the publish behind explicit confirmation. Merging them would put contradictory hard rules in one file.

## Boundary

This plugin produces **plans, gate maps, release artifacts, and the release PR**. It never:

- runs the deploy — CI/CD owns it; the service track stops at "release PR open" + "rollback playbook ready";
- pushes a version tag — the tag is created after PR merge;
- runs `gh pr merge`;
- skips the readiness check, even on a hotfix;
- writes to the architecture repository — `/implementation-plan` is read-only there.

## Dependencies

Requires `komdosh-dev-spring-core` and delegates to it: `read-service-context` (the single track-detection point), `run-verification`, `liquibase-changeset-immutability`, `check-adr-required`, `code-reviewer` (both scopes), `/add-migration` for a forward-fix changeset, `/pr-summary` for the PR body. Optional: `komdosh-dev-revealer`'s `reveal-knowledge` enriches terse commits with rationale for the changelog; `komdosh-dev-kotlin-extras`'s `/upgrade` clears `-SNAPSHOT` deps blocking `/publish-prep`.

`/jira-task` additionally requires an Atlassian MCP server, and an optional `.claude/jira.yaml` (`project: PROJ`) for the default project key.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` for internal ones).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Never reintroduce a hardcoded plugin list into `lifecycle-status` — discover the installed set.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/release-engineering.md
@rules/agentic-plan.md
