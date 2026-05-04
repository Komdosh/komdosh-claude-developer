---
name: lifecycle-status
description: Read project state (git, working tree, doc files, recent verification output) and compute the development-lifecycle gate map for the current branch. Returns a structured checklist of which gates are MET, PENDING, or N/A so the lifecycle-supervisor agent can recommend the next action. Pure read-only — never modifies code.
---

# Lifecycle Status

## When to Use

Call this skill at the start of every `lifecycle-supervisor` invocation. It is also useful standalone when an agent wants to know whether a specific gate has been crossed before doing work that depends on it.

Read-only. Never write files; never invoke other agents.

## Output

A markdown table of gates with one of three statuses:

- **MET** — the gate's criteria are satisfied
- **PENDING** — the gate is required for this branch but not yet met
- **N/A** — the gate does not apply to this change (e.g. no schema change → migration gate is N/A)

Plus a structured JSON summary at the end (the supervisor parses this; humans skim the table).

```markdown
## Lifecycle Status — <branch> @ <SHA-short>

Base: <merge-base SHA> (origin/main)
Files changed:    <N> Kotlin · <K> SQL · <M> docs
Lines changed:    +<added> -<removed>
Plugins detected: core <ver> · qa <ver> · events <ver> · platform <ver> · extras <ver> · orchestrator <ver>
                  (any of the above absent → its gates are skipped)

### Gates

| # | Gate | Status | Evidence |
|---|---|---|---|
| 1 | Requirement captured | MET     | docs/specs/2026-05-04-add-orders.md |
| 2 | Spec written         | MET     | docs/specs/2026-05-04-add-orders.md (480 lines) |
| 3 | ADR check + write    | N/A     | check-adr-required → NOT REQUIRED |
| 4 | Implementation plan  | MET     | docs/plans/2026-05-04-add-orders.md (5/5 tasks ✓) |
| 5 | Code change          | MET     | 3 controllers · 2 services · 4 DTOs |
| 6 | Tests for change     | PENDING | 1 controller test missing for OrderController |
| 7 | Migration registered | MET     | V12__create-orders.sql in db.changelog-master.yaml |
| 8 | Module-boundary scan | MET     | clean (last run: 8 files) |
| 9 | Coroutine-safety scan | MET    | clean |
| 10 | Liquibase immutability | MET   | no edits to applied changesets |
| 11 | jOOQ freshness        | PENDING | newest changeset 4m newer than generated dir |
| 12 | Full verification     | UNKNOWN | last run: never on this branch — run /verify-service |
| 13 | Code review           | PENDING | /review not run since last commit |
| 14 | QA artifacts fresh    | PENDING | docs/qa/manual-validation-plan.md older than OrderController |
| 15 | Service readiness     | UNKNOWN | last /service-health run: never on this branch |
| 16 | PR description ready  | PENDING | no PR open; /pr-summary not run |
| 17 | Release readiness     | N/A     | komdosh-dev-spring-release not installed |
| 18 | Changelog up to date  | N/A     | komdosh-dev-spring-release not installed |
| 19 | Rollback playbook     | N/A     | komdosh-dev-spring-release not installed |
| 20 | ABI delta reviewed    | N/A     | service track |
| 21 | Publish config valid  | N/A     | service track |

### Summary

```json
{
  "branch": "feat/add-orders",
  "base": "abc1234",
  "head": "def5678",
  "totals": { "met": 8, "pending": 6, "na": 1, "unknown": 2 },
  "next_recommended_gate": 11,
  "blocking_gates": [11, 12, 13, 14, 15, 16]
}
```

The `next_recommended_gate` is the **first PENDING or UNKNOWN gate** in numerical order — gates are listed in execution order so the next one to address is the next one not green.
```

## Steps

- [ ] **Step 1: Detect installed plugins**

```bash
# Walk the marketplace install path; for each known plugin name, record presence + version.
# Claude Code stores plugin metadata under one of these typical paths:
plugin_dirs=(
  "$HOME/.claude/plugins"
  "$HOME/.claude/plugins/cache"
)
for d in "${plugin_dirs[@]}"; do
  [ -d "$d" ] || continue
  for p in komdosh-dev-spring-core komdosh-dev-spring-events komdosh-dev-spring-qa \
           komdosh-dev-spring-platform komdosh-dev-spring-extras komdosh-dev-spring-orchestrator \
           komdosh-dev-spring-revealer komdosh-dev-spring-doc-revealer komdosh-dev-spring-release; do
    found=$(find "$d" -maxdepth 4 -type d -name "$p" 2>/dev/null | head -1)
    [ -n "$found" ] && version=$(jq -r '.version // "?"' "$found/.claude-plugin/plugin.json" 2>/dev/null) \
      && echo "$p $version $found"
  done
done | sort -u
```

If a plugin is absent, mark its gates **N/A**:

| Gate | Required plugin / track |
|---|---|
| QA artifacts fresh (#14) | komdosh-dev-spring-qa |
| Module-boundary scan (#8), Coroutine-safety scan (#9), Liquibase immutability (#10), jOOQ freshness (#11) | komdosh-dev-spring-core (always installed in practice) |
| Service readiness (#15) | komdosh-dev-spring-core |
| Event-consumer-specific gates (none in v1) | komdosh-dev-spring-events |
| Platform extraction gates (none in v1) | komdosh-dev-spring-platform |
| Release readiness (#17), Changelog (#18) | komdosh-dev-spring-release (both tracks) |
| Rollback playbook (#19) | komdosh-dev-spring-release AND track == service |
| ABI delta reviewed (#20), Publish config valid (#21) | komdosh-dev-spring-release AND track == library |

- [ ] **Step 2: Identify the branch and merge base**

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
head=$(git rev-parse --short HEAD)
# Try common base branches in order
for base in origin/main main origin/master master; do
  if git rev-parse --verify "$base" >/dev/null 2>&1; then
    merge_base=$(git merge-base HEAD "$base" 2>/dev/null)
    base_ref="$base"
    break
  fi
done
[ -n "$merge_base" ] || { echo "no base branch found"; exit 0; }
short_base=$(git rev-parse --short "$merge_base")
echo "branch=$branch head=$head base=$base_ref($short_base)"
```

If the branch IS `main` (no separate feature branch), still run — but treat the base as `HEAD~1` so "changes" means "the last commit". The same gates apply.

- [ ] **Step 3: Compute the changed-file inventory**

```bash
git diff --name-only "$merge_base"..HEAD > /tmp/lifecycle-changed.txt
kotlin_changed=$(grep -cE '\.kt$' /tmp/lifecycle-changed.txt || echo 0)
sql_changed=$(grep -cE '/db/changelog/V.*\.sql$' /tmp/lifecycle-changed.txt || echo 0)
controller_changed=$(grep -cE '.*Controller\.kt$' /tmp/lifecycle-changed.txt || echo 0)
test_changed=$(grep -cE '/src/test/.*\.kt$' /tmp/lifecycle-changed.txt || echo 0)
docs_changed=$(grep -cE '^docs/' /tmp/lifecycle-changed.txt || echo 0)
{
  added=$(git diff --shortstat "$merge_base"..HEAD | sed -nE 's/.* ([0-9]+) insertion.*/\1/p')
  removed=$(git diff --shortstat "$merge_base"..HEAD | sed -nE 's/.* ([0-9]+) deletion.*/\1/p')
  echo "+${added:-0} -${removed:-0}"
}
```

- [ ] **Step 4: Evaluate each gate**

Apply the rules below. For each gate emit a row of the table.

**Gate 1 — Requirement captured.**
- MET if any of: `docs/specs/*.md` newer than `merge_base`; the branch name encodes a ticket id (regex `[A-Z]+-[0-9]+`); a `BRANCH_DESCRIPTION` env var is set; or commit messages on the branch contain a `fix:` / `feat:` / `refactor:` prefix with a non-empty subject.
- PENDING otherwise.

**Gate 2 — Spec written.**
- MET if `docs/specs/*.md` newer than `merge_base` AND > 100 lines.
- N/A if the change is trivial: < 50 lines net code, no new file, no schema change, no `feat:` commit.
- PENDING otherwise.

**Gate 3 — ADR check + write.**
- Run the `check-adr-required` skill output if present in conversation memory; otherwise inspect `docs/adr/` for files newer than `merge_base`.
- MET if a new ADR exists; or if no ADR is required (no signals: no new bean, no tech-stack change, no library bump in libs.versions.toml on this branch).
- PENDING if signals suggest one is needed but none exists.

**Gate 4 — Implementation plan.**
- MET if `docs/plans/*.md` exists newer than `merge_base` AND has at least one `- [x]` checked.
- N/A if change is trivial (< 100 lines, single file).
- PENDING otherwise.

**Gate 5 — Code change.**
- MET if `kotlin_changed > 0`.
- PENDING if no code changes yet but a spec/plan exists (you've planned but not started).

**Gate 6 — Tests for change.**
- For each changed `*Controller.kt`, look for a corresponding `*ControllerTest.kt` modified on this branch.
- For each changed `application/.../<X>Service.kt`, look for `<X>ServiceTest.kt` modified on this branch.
- MET if every changed prod file has a corresponding test file changed.
- PENDING with a list of files lacking corresponding tests.
- N/A if no Kotlin changes.

**Gate 7 — Migration registered.**
- MET if every new `V*.sql` (in the `git diff --diff-filter=A` for `merge_base..HEAD`) is referenced in some `db.changelog-master.yaml` AND that yaml was updated on this branch.
- PENDING with the list of unregistered files.
- N/A if no SQL changes.

**Gate 8 — Module-boundary scan.**
- Run `module-boundary-check` skill (or read its cached last-run output if available within the same session). MET on CLEAN; PENDING with violation count.
- N/A if no Kotlin changes under `domain/`, `application/`, `adapters/`.

**Gate 9 — Coroutine-safety scan.**
- Run `coroutine-safety-scan` skill on changed files. MET on CLEAN; PENDING with violation count.
- N/A if no Kotlin changes.

**Gate 10 — Liquibase immutability.**
- Run `liquibase-changeset-immutability` skill. MET if no applied changesets were edited; PENDING with the list.
- N/A if no `V*.sql` exists in the repo.

**Gate 11 — jOOQ freshness.**
- Run `jooq-generation-freshness` skill. MET on FRESH; PENDING on STALE.
- N/A if jOOQ codegen is not configured in this project.

**Gate 12 — Full verification.**
- Look for `build/test-results/test/TEST-*.xml` mtimes ≥ HEAD commit time AND no `<failure>` or `<error>` children.
- MET if all green; PENDING if any failure or stale; UNKNOWN if no test results exist.

**Gate 13 — Code review.**
- Best-effort: look for a marker file `docs/.last-review.json` (the `change-reviewer` agent could write one when it runs cleanly). If absent or older than HEAD, mark PENDING/UNKNOWN. If present and ≥ HEAD with `blockers: 0`, MET.
- (Plan: `change-reviewer` may need a tiny update to drop a marker — note this as an optional follow-up; for v1 just always recommend running `/review` after code changes.)

**Gate 14 — QA artifacts fresh.**
- N/A if `komdosh-dev-spring-qa` plugin not installed.
- MET if `docs/qa/manual-validation-plan.md` mtime ≥ newest `*Controller.kt` mtime AND the same is true for `docs/qa/postman/*.json` and `docs/qa/qa-console.html`.
- PENDING with the list of stale artifacts.

**Gate 15 — Service readiness.**
- Look for a marker file `docs/.last-readiness-audit.json` (similar to gate 13).
- For v1, just mark UNKNOWN unless such a marker is found, and recommend `/service-health` if the change is non-trivial.

**Gate 16 — PR description ready.**
- MET if `gh pr view --json body -q .body` (when authenticated) returns non-empty.
- PENDING otherwise.
- N/A if `gh` CLI is not installed or no remote PR exists yet.

**Gates 17–21 — Release engineering.**

These gates apply only when `komdosh-dev-spring-release` is installed. When the plugin is absent, all five report `N/A`.

For gates 19–21, the gate is also conditional on **track**: detect the project's track (service vs library) once and skip the wrong-track gates:

```bash
# track detection (mirrors release-coordinator Step 2)
kind=""
[ -f service.yaml ] && kind=$(grep -E '^kind:\s*' service.yaml | awk '{print $2}' | tr -d '"' | head -1)
[ -f service.yml ] && kind=${kind:-$(grep -E '^kind:\s*' service.yml | awk '{print $2}' | tr -d '"' | head -1)}
if [ -z "$kind" ]; then
  has_publish=$(grep -lE 'maven-publish' build.gradle.kts 2>/dev/null | head -1)
  has_app=$(find . -name 'Application.kt' -not -path '*/build/*' -not -path '*/test/*' \
             -exec grep -lE 'runApplication<' {} + 2>/dev/null | head -1)
  has_dockerfile=$(find . -maxdepth 3 -name 'Dockerfile' | head -1)
  has_boot=$(grep -lE 'org\.springframework\.boot' build.gradle.kts 2>/dev/null | head -1)
  if [ -n "$has_publish" ] && [ -z "$has_boot" ] && [ -z "$has_app" ]; then kind="library";
  elif [ -n "$has_boot" ] && [ -n "$has_app" ] && [ -n "$has_dockerfile" ]; then kind="service";
  fi
fi
```

If `kind` cannot be determined, all five gates report `UNKNOWN` (not `PENDING`) and recommend setting `kind:` in `service.yaml`.

**Gate 17 — Release readiness.**
- N/A if release plugin not installed.
- Run `verify-release-readiness-service` (track=service) or `verify-release-readiness-library` (track=library) skill.
- MET if composite is PASS; PENDING if composite is FAIL.
- The skill itself reports `N/A` for sub-gates that don't apply (e.g. QA artifacts on a project without the qa plugin) — those don't block this gate.

**Gate 18 — Changelog up to date.**
- N/A if release plugin not installed.
- MET if `CHANGELOG.md` exists AND its most-recent non-Unreleased section's date is YYYY-MM-DD format AND its version matches the project's current version.
- PENDING otherwise.

**Gate 19 — Rollback playbook present.**
- N/A if release plugin not installed OR `kind == library`.
- MET if `docs/release/playbooks/v<current-version>.md` exists AND there are no NEW migrations in `last_tag..HEAD` that aren't documented in the playbook.
- N/A if no NEW migrations exist in the release window.
- PENDING otherwise.

**Gate 20 — ABI delta reviewed.**
- N/A if release plugin not installed OR `kind == service`.
- MET if `docs/release/abi-v<current-version>.md` exists AND its mtime ≥ HEAD commit time AND the report's recommended-bump matches the project's current version bump (no breaking deltas going into a non-major release).
- PENDING otherwise.

**Gate 21 — Publish config valid.**
- N/A if release plugin not installed OR `kind == service`.
- Run `check-publish-config` skill.
- MET if BLOCKERS == 0 (WARN-only is OK).
- PENDING if BLOCKERS > 0.

- [ ] **Step 5: Compose the table + JSON summary**

Render the markdown table per the Output section. Build the JSON summary:

```json
{
  "branch": "<branch>",
  "base":   "<short-base>",
  "head":   "<short-head>",
  "totals": { "met": <N>, "pending": <K>, "na": <M>, "unknown": <U> },
  "next_recommended_gate": <first PENDING-or-UNKNOWN by gate number>,
  "blocking_gates": [<list of all PENDING-or-UNKNOWN gate numbers>]
}
```

`next_recommended_gate` is the gate the supervisor should suggest acting on next. Tie-breaker: lower gate number wins.

- [ ] **Step 6: Hand back**

Print the table + JSON. Do not invoke any agent. The calling agent (`lifecycle-supervisor` or another) decides what to do next.

## Notes

- This skill is read-only. It runs the other skills (`module-boundary-check`, `coroutine-safety-scan`, `liquibase-changeset-immutability`, `jooq-generation-freshness`) for evaluation but never modifies code or commits.
- Sub-skill execution can be expensive on large branches. If the calling agent only needs a partial view, it can pass `--gates 1-5` to scope (the agent should respect this hint and emit `SKIPPED` for gates outside the range).
- For projects that don't use `docs/plans/` and `docs/specs/` (using a different planning tool), the gate evaluation can return `N/A` once configured by the team. A future enhancement: `service.yaml` could declare `lifecycle.spec_dir` and `lifecycle.plan_dir` to override defaults.
