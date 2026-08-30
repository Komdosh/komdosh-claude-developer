# Agentic Implementation Plan

For any plan produced by `implementation-planner`. **The architecture repository's own `plan-service-implementation` contract is the authority when present** — this file adds the marketplace overlay (executor mapping, citation discipline) and keeps a frozen fallback structure for when the repo ships no such contract.

## Every todo names its executor

| Write scope | Executor |
|---|---|
| New service skeleton | `core/service-bootstrapper` |
| Domain model, use cases, ports, business logic | `core/backend-implementer` |
| HTTP endpoint | `/add-endpoint` |
| Schema change | `/add-migration` |
| Broker consumer | `core/event-consumer-author` |
| Avro schema + event DTOs | `/avro-new-event` → `core/avro-schema-author` |
| Config, Gradle, containers, observability, auth | `core/backend-implementer`, per the matching core rule |
| Kubernetes / ArgoCD / Terraform / CI | the `komdosh-dev-infra-*` plugins |
| Tests | `core/test-writer` |
| Vendor decoupling | `/audit-leaks` → `quality/platform-developer` |
| QA artifacts | `/qa` |
| Within-service decision | `/adr-new` |
| **Cross-service or durable decision** | the **architecture repo's** ADR workflow — never a service-repo ADR |
| Release prep, changelog, rollback playbook | this plugin's commands |

`run-verification` is implied after every code-writing todo, not listed per row.

**A todo with no matching executor is a smell**: either the scope is too broad (split it) or it isn't implementation work (move it to Blocking Decisions, or to the architecture repo).

## Citation discipline

- Every Source Inventory row and every ADR constraint carries an **exact path** in the architecture repo, or an explicit `index-derived` marker when discovery ran in RAG mode.
- **Facts, evidence-backed inferences, and assumptions are labelled as such.** An unlabelled claim is an error in review.
- Point at sources; never quote more than needed.

## Placement and lifecycle

`docs/plans/<YYYY-MM-DD>-<service>-implementation-plan.md` — the directory core's `/continue-plan` resumes from.

Re-runs **preserve completed todo state** where ID and write scope are unchanged; everything else regenerates and the report lists what changed.

**A plan with unresolved P0 ADR blockers is `Status: Blocked`**, and implementation must not start P1 work depending on a blocked P0.

## Fallback structure

Used only when the architecture repo provides no contract of its own; **if its contract evolves, its version wins.**

```markdown
# Implementation Agentic Plan: [Service]

## Status                 Draft | Ready for Review | Blocked
## Scope                  service · target repo · target modules · milestone · non-goals
## Source Inventory       | Source | Path / Evidence | What It Constrains | Confidence |
## Service Contract Summary
                          ownership · source of truth · key APIs · key events ·
                          correctness-sensitive flows · business invariants · ADR constraints
## Current Implementation State
                          existing modules · reusable code · missing pieces · maturity
## Blocking Decisions     | Blocker | Why It Blocks | Owner / Needed Input | Plan Impact |
## Agent Execution Rules  preserve unrelated user changes · read referenced docs before editing ·
                          keep write scopes narrow · no secrets or runtime-only assumptions
## Ordered Todos          | ID | Priority | Task | Inputs to Read | Write Scope |
                          | Acceptance Criteria | Verification | Dependencies | Executor |
## Test and Verification Matrix   | Area | Required Coverage | Evidence / Command | Owner |
## Rollout                migration sequence · rollout guards · rollback or compensation ·
                          observability and runbooks · release-readiness checks
## Risks                  | Risk | Impact | Mitigation | Trigger to Escalate |
## Definition of Done     every source constraint traceable · P0–P1 todos carry acceptance criteria
                          and verification · correctness-sensitive flows covered (idempotency, retry,
                          replay, reconciliation, observability) · contract and migration changes tested
```

Priorities: **P0** blockers and correctness foundations · **P1** required scope · **P2** pre-release hardening · **P3** post-milestone polish.

## Quality bar

Concrete ordered tasks, not broad phases · executable by another agent with **zero hidden context** · write scopes disjoint enough for safe parallel agents · verification present even when the planning session cannot run the target's tests · **unverified implementation state stated honestly, never invented**.
