---
name: discover-architecture-context
user-invocable: false
description: Locate the company architecture repository, resolve one service's architecture package inside it, and assemble a tiered evidence inventory (entry contracts, service package, domain top-level, system top-level, ADR constraints, business scope/roadmap, dev-ex standards, canonical plan contract). Read-only on the architecture repo. Returns a structured descriptor consumed by the implementation-planner agent. Degrades to code-RAG MCP search when the repo is not on local disk.
---

# Discover Architecture Context

Resolve the architecture repository and build the complete evidence inventory for one service. Read-only everywhere — this skill never modifies the architecture repo or the current project.

Track each step as a todo when invoked.

## Inputs

- `service` (required) — service name in any form: GitLab slug (`social-media-processor`) or directory form (`social_media_processor`). Normalise both ways: slug uses dashes, architecture directories use underscores.
- `arch_repo` (optional) — explicit path from `--arch-repo=`.
- `domain` (optional) — bounded-context hint from `--domain=` (e.g. `social-media`).

## Step 1: Resolve the architecture repository

Walk this ladder; stop at the first hit. Record which rung won — it goes into the descriptor as `arch_repo_source`.

1. Explicit `--arch-repo=` argument.
2. `.claude/architecture.yaml` in the current project: read `repo:` (absolute or relative path), optional `domain:`.
3. Well-known locations, in order: `~/Projects/lookstream/architecture/architecture`, `../architecture/architecture`, `../../architecture/architecture` (relative to the current project root).
4. **MCP degraded mode** — if no local path exists but a code-RAG MCP is configured (`lookstream-code-rag`: try `federated_search` / `hybrid_search` scoped to the architecture collection; or `codebase-memory`), mark `access: rag` and answer every later step through search instead of file reads. State explicitly in the descriptor that file paths are index-derived, not verified on disk.
5. Nothing found → STOP. Ask the user for the path and suggest persisting it:
   ```yaml
   # .claude/architecture.yaml
   repo: /absolute/path/to/architecture
   ```

Sanity-check the resolved directory: it must contain `adr/` and `top-level/` (or, for RAG mode, the index must return hits for both). A directory that fails the check is not the architecture repo — keep walking the ladder.

## Step 2: Read the repo's own entry contract first

The architecture repo prescribes how agents must navigate it. Read, in order, whichever exist:

1. `AGENTS.md` — repository-level AI contract, safety constraints.
2. `AI_START_HERE.md` — task-type router; find the `plan-service-implementation` route and note the template/playbook it points at.
3. `.agents/context/repo-map.md` — authoritative document locations. **Prefer this map over the hardcoded paths below whenever they disagree.**
4. `.agents/context/architecture-baseline.md` — default stack constraints.
5. `.agents/context/business-invariants.md` — rules the plan must never contradict.

## Step 3: Locate the service architecture package

1. Convert the service name to directory form (`social-media-processor` → `social_media_processor`).
2. Search `top-level/contexts/*/*/services/<service_dir>/` (contexts are grouped, e.g. `core/`, `utility/`, `analytics/`; the domain level sits between group and `services/`).
3. Found → record `domain` (e.g. `social-media`), `context_group` (e.g. `core`), and list **every** `.md` in the service package. The package `README.md` is the index — read it fully; extract its "Key ADR constraints" (or equivalent) list.
4. Not found → list available services under `top-level/contexts/*/*/services/` and STOP: report the candidates and ask the user to pick or confirm the service is genuinely new. A new service (no package yet) is a **plan-service-architecture problem, not an implementation-plan problem** — say so explicitly and recommend running the architecture repo's `plan-service-architecture` workflow first.

## Step 4: Assemble the tiered evidence inventory

Collect paths per tier. Do not read everything yet — the inventory records *what exists and why it matters*; the planner reads selectively.

| Tier | What | Where |
|---|---|---|
| T0 entry | AI contract, router, repo map, baseline, invariants | files from Step 2 |
| T1 service | the full service architecture package (architecture, domain model, data, API/event contracts, runtime, security, observability, risk register, readiness checklist — whatever the README indexes) | `top-level/contexts/<group>/<domain>/services/<service_dir>/*.md` |
| T2 domain | area-level architecture + sibling-service boundaries | `top-level/contexts/<group>/<domain>/*.md`, the domain's `services/` listing |
| T3 system | system boundaries, shared libraries, infrastructure baseline | `top-level/Backend_Top_Level_Architecture.md`, `top-level/Backend_Shared_Libraries.md`, `top-level/Infrastructure_Top_Level_Plan.md` |
| T4 ADRs | every ADR constraining this service | the service README's key-ADR list, plus `adr/backend/README.md` index scanned for the service's concerns (storage, events, IDs, migrations, observability, security, testing, rollout); include `adr/infrastructure/` and `adr/analytics/` when the service touches them |
| T5 business | what the service must support and when | `business/MVP_product_scope.md` (relevant sections), `business/schedule/by-domain/<Domain>_roadmap_*.md`, `business/events/` if the service publishes analytics events |
| T6 dev-ex | standards the todos must obey | `dev-ex/Coding_Standard.md`, `dev-ex/Testing_Standard.md`, `dev-ex/backend/*.md` (server coding/testing/naming/project-structure), `dev-ex/Release_Readiness_Standard.md` |
| T7 contract | the canonical plan output contract | `.agents/skills/plan-service-implementation/SKILL.md` and `.agents/skills/plan-service-architecture/references/ArchitecturePlanningGuide.md` |

For each entry record: path, tier, one-line "what it constrains", and confidence (`verified` for files read/listed on disk, `index-derived` for RAG hits).

## Step 5: Probe current implementation state (best effort)

If the target implementation repo is identifiable (current working directory, or named in the service package):

- Prefer MCP graph/RAG (`codebase-memory`, `lookstream-code-rag`) to inventory existing modules, entrypoints, migrations.
- Fall back to filesystem listing when the repo is local.
- Neither available → set `implementation_state: unverified`. **Never invent code reality.**

## Step 6: Return the descriptor

```json
{
  "arch_repo": "<path>",
  "arch_repo_source": "flag | architecture.yaml | well-known | rag",
  "access": "filesystem | rag",
  "service": "<slug>",
  "service_dir": "<underscored>",
  "domain": "<domain>",
  "context_group": "<group>",
  "service_package": ["<paths>"],
  "evidence": [ { "path": "...", "tier": "T0-T7", "constrains": "...", "confidence": "verified | index-derived" } ],
  "key_adrs": ["BADR-NNNN ..."],
  "plan_contract": "<path to plan-service-implementation SKILL.md, or null>",
  "implementation_state": "verified | unverified",
  "gaps": ["evidence that should exist but was not found"]
}
```

`gaps` is load-bearing: missing readiness checklists, missing ADR index entries, or a service package with no data-architecture doc become Blocking Decisions / Open Questions in the plan.
