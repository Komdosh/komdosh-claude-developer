# komdosh-dev-spring-delivery

Everything between "a ticket exists" and "the release PR is open", on top of `komdosh-dev-spring-core`. One pipeline in four phases: **enter work → plan it → track it to done → ship it.**

## Two invariants that keep being rediscovered

**The installed-plugin set is discovered at runtime, never hardcoded.** A fixed list goes stale the moment the marketplace ships a plugin, and every gate belonging to an unlisted plugin then vanishes from the map silently — which is exactly what happened before. An undetectable plugin yields **UNKNOWN, not MET**.

**`release-coordinator` and `library-publisher` stay separate on purpose.** One is bound by "never deploys, never publishes" and stops at PR-open; the other performs the publish behind explicit confirmation. Merging them would put contradictory hard rules in one file.

## Tracks

Detection order: `service.yaml`'s `kind` → core's `read-service-context` heuristics → a `--track=` override. **Ambiguity stops and asks once** rather than guessing.

Both tracks: `/release-prep`, `/changelog`, `/version-bump`, `/release-notes`.
Service adds `/rollback-playbook`. Library adds `/abi-check`, `/publish-prep`, `/deprecate-api` — and there the version bump is **ABI-load-bearing**: a breaking ABI delta forces major regardless of commit prefixes.

The changelog section is written by the `write-changelog` **skill, inline** — a deterministic git-log-to-markdown transform, so running it as an agent was a nested subagent hop that bought no isolation.

## Boundary

Produces plans, gate maps, release artifacts, and the release PR. **Never** runs the deploy (CI/CD owns it; the service track stops at "release PR open" + "rollback playbook ready"), **never** pushes a version tag (created after merge), **never** runs `gh pr merge`, **never** skips the readiness check — not even on a hotfix — and **never writes to the architecture repository**; `/implementation-plan` is read-only there.

## Composition

Delegates to core: `read-service-context` (the single track-detection point), `run-verification`, `liquibase-changeset-immutability`, `check-adr-required`, `code-reviewer`, `/add-migration` for a forward-fix changeset, `/pr-summary` for the PR body.

Optional: `revealer`'s `reveal-knowledge` enriches terse commits for the changelog; `kotlin-extras`'s `/upgrade` clears `-SNAPSHOT` deps blocking `/publish-prep`.

`/jira-task` requires an Atlassian MCP server, plus an optional `.claude/jira.yaml` (`project: PROJ`) for the default project key.

For a spec from free text rather than an architecture repo, use core's `/analyze-requirements`.

@rules/release-engineering.md
@rules/agentic-plan.md
