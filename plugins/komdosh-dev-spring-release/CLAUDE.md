# CLAUDE.md — komdosh-dev-spring-release

Release engineering on top of `komdosh-dev-spring-core`. Two tracks under one plugin: **service** (microservices deployed to k8s) and **library** (shared Kotlin libraries published to Maven Central / GitHub Packages). The plugin auto-detects which track applies and runs the matching gates.

## What it adds

### Service track

| Command | Agent / Skill | What it does |
|---|---|---|
| [`/release-prep`](commands/release-prep.md) | [`release-coordinator`](agents/release-coordinator.md) → [`verify-release-readiness-service`](skills/verify-release-readiness-service/SKILL.md) | Composite gate run: tests green, migrations idempotent, QA artifacts fresh, no `// TODO(release)` markers, no uncommitted changes, ADRs exist for new architectural surface. Output is a checklist with PASS / FAIL / SKIP per gate and the next action per FAIL. |
| [`/changelog`](commands/changelog.md) | [`changelog-writer`](agents/changelog-writer.md) | Conventional-Commits → grouped CHANGELOG.md entry under `## [vX.Y.Z] — YYYY-MM-DD`. |
| [`/version-bump`](commands/version-bump.md) | [`detect-release-type`](skills/detect-release-type/SKILL.md) | Reads commits since last tag, classifies major/minor/patch via Conventional Commits + breaking footers, updates the version source. |
| [`/release-notes`](commands/release-notes.md) | `release-coordinator` | Customer-facing highlights for the deploy announcement (no internal refactor noise). |
| [`/rollback-playbook`](commands/rollback-playbook.md) | [`produce-rollback-playbook`](skills/produce-rollback-playbook/SKILL.md) | Per migration in scope: inverse SQL where mechanically possible; "forward-fix only" with rationale otherwise. Surfaces ENV / feature-flag toggles that must move with rollback. |

### Library track

| Command | Agent / Skill | What it does |
|---|---|---|
| [`/release-prep`](commands/release-prep.md) | [`release-coordinator`](agents/release-coordinator.md) → [`verify-release-readiness-library`](skills/verify-release-readiness-library/SKILL.md) | Library-flavored composite gate: tests green, no internal-API leakage in public packages, ABI report reviewed, deprecations have replacement annotations and sunset versions, KDoc present on all public symbols, sources/javadoc jars produced, no `-SNAPSHOT` deps, license headers present. |
| [`/changelog`](commands/changelog.md) | [`changelog-writer`](agents/changelog-writer.md) | Same as service track. Audiences differ; format is identical. |
| [`/version-bump`](commands/version-bump.md) | [`detect-release-type`](skills/detect-release-type/SKILL.md) + [`produce-abi-report`](skills/produce-abi-report/SKILL.md) | Library bumps are **ABI-load-bearing** — a breaking ABI change forces major regardless of commit prefixes. |
| [`/release-notes`](commands/release-notes.md) | `release-coordinator` | Public artifact release notes; emphasize migration guidance for consumers. |
| [`/abi-check`](commands/abi-check.md) | [`produce-abi-report`](skills/produce-abi-report/SKILL.md) | Diffs the public API surface against the last released tag (`kotlinx.binary-compatibility-validator` or japicmp). Per-symbol classification: added / deprecated / changed-signature / removed. |
| [`/publish-prep`](commands/publish-prep.md) | [`check-publish-config`](skills/check-publish-config/SKILL.md) | Validates Maven coordinates, POM completeness (developers, scm, license), signing config, repository creds reachable, sources/javadoc jars configured, no `-SNAPSHOT` deps. Read-only. |
| [`/deprecate-api`](commands/deprecate-api.md) | [`library-publisher`](agents/library-publisher.md) | Mark a public symbol `@Deprecated(...)` with replacement, set sunset version, add a CHANGELOG breadcrumb, surface known internal call-sites. |

Hook (auto-installed via `hooks/hooks.json`):

- `pre-tag-validation.sh` — fires `PreToolUse` on `Bash` when the command starts with `git tag` (excluding `-d`, `-l`, `--list`, and the bare list form). Detects the track via `service.yaml` `kind:` (or build heuristics), then prints a reminder to run `/release-prep --track=<detected>` first. Advisory only (exit 0) — never invokes the readiness skill itself, never blocks the tag. The actual validation lives in `verify-release-readiness-{service,library}`; the hook's job is to surface that the user should run it before the tag command actually creates the tag.

Rules:

- [`rules/release-engineering.md`](rules/release-engineering.md) — Conventional Commits required, semver discipline, what counts as breaking, CHANGELOG format. Track-specific sections: rollback decision tree (service) vs. ABI / deprecation policy (library).

## Track auto-detection

The plugin detects which track applies before running gate logic. Order of precedence:

1. **`service.yaml` declares it.** New optional field: `kind: service | library`. If present, that wins.
2. **Build heuristics** (run by `release-coordinator`):
   - `maven-publish` plugin applied + no `org.springframework.boot` plugin + no `Application.kt` containing `runApplication<>` → **library**.
   - `org.springframework.boot` plugin applied + `Dockerfile` (or k8s manifests under `infra/` / `deploy/`) present → **service**.
3. **User override** — `--track=service` or `--track=library` on any command short-circuits detection.

If ambiguous, commands stop and ask the user once.

The `read-service-context` skill in core emits a `kind` field in its summary so callers don't re-detect.

## Dependencies

Requires `komdosh-dev-spring-core`. Delegates to:

- `service-readiness-auditor` (core) — wrapped by `verify-release-readiness-service`.
- `run-verification`, `liquibase-changeset-immutability`, `check-adr-required` (core) — sub-skills in both readiness skills.
- `migration-writer` (core) — when a forward-fix migration must be authored as part of a rollback playbook.
- `build-expert` (core) — for any final Gradle publishing config tweaks the `library-publisher` cannot make safely on its own.
- `change-reviewer` (core) — for the release PR review pass.
- `pr-summary` (core) — release-flavored variant for the release PR description.
- `reveal-knowledge` (revealer plugin, optional) — `changelog-writer` enriches terse commits with rationale when revealer is installed.

## Boundary

This plugin produces **release artifacts and the release PR**. It does NOT:

- Run the actual deploy. Service track stops at "release PR open" + "rollback playbook ready"; CI/CD owns the deploy itself.
- Push tags or run `gh pr merge`. The supervisor's safety rules apply — destructive remote operations always require explicit user confirmation.
- Bump dependencies. That's `extras/dependency-upgrader`.

@rules/release-engineering.md
