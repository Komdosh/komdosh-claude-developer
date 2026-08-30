---
name: lifecycle-status
user-invocable: false
description: Read project state (git, working tree, doc files, recent verification output) and compute the development-lifecycle gate map for the current branch. Returns a structured checklist of which gates are MET, PENDING, or N/A so the lifecycle-supervisor agent can recommend the next action. Pure read-only — never modifies code.
---

# Lifecycle Status

Computes the gate map for the current branch. **Read-only**: it runs read-only sub-skills to evaluate gates, but never writes and never invokes an agent.

Statuses: **MET** · **PENDING** (required here, not yet met) · **N/A** (doesn't apply) · **UNKNOWN** (cannot be determined — never treat as MET).

## 1. Discover the installed plugins — never hardcode the list

A hardcoded list goes stale the moment the marketplace ships a plugin, and that plugin's gates then disappear from the map without a word.

```bash
for d in "$HOME/.claude/plugins" "$HOME/.claude/plugins/cache"; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 5 -type f -path '*/.claude-plugin/plugin.json' 2>/dev/null | while read -r m; do
    name=$(jq -r '.name // ""' "$m" 2>/dev/null)
    case "$name" in komdosh-dev-*) printf '%s %s\n' "$name" "$(jq -r '.version // "?"' "$m")" ;; esac
  done
done | sort -u
```

**An undetectable plugin is not an absent one** — if the scan returns nothing, say so and report every plugin-dependent gate as UNKNOWN. A gate is N/A only when its plugin is *confirmed* absent.

Gate ownership: 8–11, 13, 15 → `spring-core` · 14 → `spring-quality` · 17–21 → `spring-delivery`. Report any installed `komdosh-dev-*` plugin the map doesn't name, so a newly-shipped plugin surfaces as a visible gap rather than vanishing.

## 2. Establish the branch, base, and diff

Try `origin/main`, `main`, `origin/master`, `master` for the base and take the merge base. **On `main` itself, use `HEAD~1`** so "the change" means the last commit — the same gates still apply.

Count changed Kotlin, `V*.sql`, controller, test, and doc files, plus the insertion/deletion totals. Those counts drive the N/A rules below.

## 3. Gates

| # | Gate | MET when | N/A when |
|---|---|---|---|
| 1 | Requirement captured | a spec newer than base, a ticket id in the branch name, or a Conventional-Commit subject on the branch | — |
| 2 | Spec written | `docs/specs/*.md` newer than base, >100 lines | trivial change: <50 net lines, no new file, no schema change, no `feat:` |
| 3 | ADR check + write | a new ADR exists, or no signal calls for one (no new bean, tech-stack change, or catalog bump) | — |
| 4 | Implementation plan | `docs/plans/*.md` newer than base with ≥1 `- [x]` | trivial: <100 lines, single file |
| 5 | Code change | Kotlin files changed | — |
| 6 | Tests for change | every changed prod file has a matching test file changed on this branch | no Kotlin changes |
| 7 | Migration registered | every **added** `V*.sql` appears in a `db.changelog-master.yaml` updated on this branch | no SQL changes |
| 8 | Module-boundary scan | `module-boundary-check` CLEAN | no changes under `domain`/`application`/`adapters` |
| 9 | Coroutine-safety scan | `coroutine-safety-scan` CLEAN | no Kotlin changes |
| 10 | Liquibase immutability | `liquibase-changeset-immutability` clean | no `V*.sql` in the repo |
| 11 | jOOQ freshness | skill reports FRESH | no jOOQ codegen configured |
| 12 | Full verification | `build/test-results/test/TEST-*.xml` newer than HEAD with no `<failure>`/`<error>` | — (UNKNOWN when no results exist) |
| 13 | Code review | **never MET — see below** | — |
| 14 | QA artifacts fresh | each `docs/qa/*` artifact newer than the newest `*Controller.kt` | quality plugin absent |
| 15 | Service readiness | **never MET — see below** | — |
| 16 | PR description ready | `gh pr view --json body` returns non-empty | no `gh`, or no PR yet |
| 17 | Release readiness | `verify-release-readiness-{track}` composite PASS | delivery plugin absent |
| 18 | Changelog up to date | the newest non-Unreleased section's version matches the project version | delivery plugin absent |
| 19 | Rollback playbook | `docs/release/playbooks/v<version>.md` covers every migration added since the last tag | delivery absent · library track · no new migrations |
| 20 | ABI delta reviewed | `docs/release/abi-v<version>.md` newer than HEAD, and its recommended bump matches the version chosen | delivery absent · service track |
| 21 | Publish config valid | `check-publish-config` reports 0 BLOCKERs (WARN is fine) | delivery absent · service track |

### Gates 13 and 15 are UNKNOWN by design

Nothing in the marketplace writes a "review ran cleanly" or "readiness audit ran" marker, and **`code-reviewer` is read-only at the tool layer, so it cannot write one.** Report both as UNKNOWN with that reason and recommend `/review` and `/service-health` after any non-trivial change. Do not invent a marker file and do not infer MET from its absence — a gate that cannot be measured is not a gate that passed.

### Track conditions on 19–21

**Do not re-implement track detection.** Take `kind` from core's `read-service-context` — the marketplace's single source of truth — and reuse this session's earlier result rather than re-invoking it.

`service` → 19 applies, 20–21 N/A. `library` → 19 N/A, 20–21 apply. **`unknown` → all five report UNKNOWN, not PENDING**, and recommend setting `kind:` in `service.yaml`.

## 4. Emit

The markdown table with per-gate evidence, then:

```json
{ "branch": "…", "base": "…", "head": "…",
  "totals": { "met": 0, "pending": 0, "na": 0, "unknown": 0 },
  "next_recommended_gate": 0, "blocking_gates": [] }
```

`next_recommended_gate` is the **first PENDING-or-UNKNOWN by number** — gates are in execution order, so the next one not green is the next one to address.

Sub-skill runs are expensive on a large branch: honour a `--gates N-M` hint from the caller and emit `SKIPPED` outside that range. Where a project uses different spec/plan directories, those gates are N/A until configured.
