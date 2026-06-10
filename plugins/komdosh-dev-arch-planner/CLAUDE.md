# CLAUDE.md — komdosh-dev-arch-planner

Architecture-driven implementation planning on top of `komdosh-dev-spring-core`. One job: given a service name, turn the company **architecture repository** (ADRs, per-service architecture packages, domain top-level docs, business scope, dev-ex standards) into a **whole-service implementation agentic plan** another agent can execute.

## What it adds

| Piece | Purpose |
|---|---|
| [`/implementation-plan <service>`](commands/implementation-plan.md) | Entry point. `--domain=`, `--arch-repo=`, `--milestone=` optional. |
| [`implementation-planner`](agents/implementation-planner.md) | Opus planner. Discovers evidence, adopts the architecture repo's own plan contract, writes `docs/plans/<date>-<service>-implementation-plan.md`. Never writes service code, never modifies the architecture repo. |
| [`discover-architecture-context`](skills/discover-architecture-context/SKILL.md) | Internal skill. Resolves the architecture repo (flag → `.claude/architecture.yaml` → well-known paths → code-RAG MCP degraded mode), locates the service package under `top-level/contexts/`, assembles the tiered evidence inventory (T0 entry contracts → T7 plan contract), probes current implementation state, reports gaps. |
| [`rules/agentic-plan.md`](rules/agentic-plan.md) | Executor mapping (todo write scope → marketplace agent/command), citation discipline, plan placement, and a frozen fallback output contract. |

## The defer-to-source design

The architecture repo is expected to ship its own canonical `plan-service-implementation` contract (under `.agents/skills/`). When it does, **that contract is the authority** — workflow, output format, readiness checks, stop conditions. This plugin operationalises it from the service-repo side: resolution, evidence assembly, MCP-backed implementation-state probing, executor mapping onto this marketplace's agents, and placement where core's `/continue-plan` resumes. When the architecture repo has no contract, `rules/agentic-plan.md` carries a frozen fallback of the same structure.

This keeps the plan format owned by the architecture team, not by plugin releases.

## Configuration

Optional `.claude/architecture.yaml` in the implementation repo:

```yaml
repo: /absolute/path/to/architecture   # architecture repo root
domain: social-media                   # optional bounded-context hint
```

Without it the skill tries well-known sibling paths, then code-RAG MCP (`lookstream-code-rag`, `codebase-memory`) in degraded mode, then asks once.

## Boundaries

- **Read-only on the architecture repo.** Follow-ups that belong there (new ADR, doc fix) become plan todos pointing at the architecture repo's own playbooks.
- **Plans services, not features.** A single feature inside an existing service is `requirements-analyst` (core).
- **Does not decide architecture.** Undecided ownership / source of truth / failure model → the planner stops and redirects to the architecture repo's `plan-service-architecture` workflow.
- **Does not execute the plan.** Hand off to `/lifecycle orchestrate` (orchestrator) or `backend-implementer` (core); the plan's Executor column says which agent runs which todo.

@rules/agentic-plan.md
