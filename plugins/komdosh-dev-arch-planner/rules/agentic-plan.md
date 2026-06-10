# Agentic Implementation Plan Rules

Rules for any plan produced by `implementation-planner`. The architecture repository's own `plan-service-implementation` contract is the **authority** when present; this file adds the marketplace overlay (executor mapping, citation discipline) and carries a frozen fallback copy of the contract's structure for when the architecture repo doesn't ship one.

## Executor mapping — every todo names who runs it

Each ordered todo carries an **Executor** column: the marketplace agent or command an implementation session uses for that write scope. Standard mapping:

| Todo write scope | Executor |
|---|---|
| New service skeleton (leaf modules, Gradle wiring) | `core/service-bootstrapper` |
| Domain model, use cases, ports, business logic | `core/backend-implementer` |
| HTTP endpoint (controller + DTO + wiring) | `/add-endpoint` (core) |
| Schema change / Liquibase changeset | `/add-migration` → `core/migration-writer` |
| Kafka/SQS/RabbitMQ consumer | `events/event-consumer-author` |
| Avro schema + generated event DTOs | `/avro-new-event` → `avro/avro-schema-author` |
| Spring config, profiles, feature flags | `core/config-expert` |
| Gradle / version catalog | `core/build-expert` |
| Docker/k8s/CI | `core/infra-expert` |
| Metrics, traces, structured logging | `core/observability-expert` |
| AuthN/AuthZ filters, protected routes | `core/security-expert`; post-hoc audit via `/security-audit` (security) |
| Tests (unit / integration / architecture) | `core/test-writer` |
| Vendor-decoupling / common module extraction | `/audit-leaks` → `platform/platform-developer` |
| QA artifacts (manual plan, Postman, console) | `/qa-plan` `/qa-postman` `/qa-console` (qa) |
| Captured architectural decision (within service) | `/adr-new` → `core/adr-writer` |
| Cross-service / durable decision (ADR blocker) | the **architecture repo's** `new-adr` playbook — not a service-repo ADR |
| Release prep, changelog, rollback playbook | `/release-prep` `/changelog` `/rollback-playbook` (release) |
| Verification after any code todo | `run-verification` skill (core) — implied for every code-writing todo, not listed per-row |

A todo whose write scope has no matching executor is a smell: either the scope is too broad (split it) or it's not implementation work (move it to Blocking Decisions or to the architecture repo's workflows).

## Citation discipline

- Every row of the Source Inventory and every ADR constraint carries an exact path inside the architecture repo (or an `index-derived` marker when discovery ran in RAG mode).
- Facts, evidence-backed inferences, and assumptions are labelled as such. An unlabelled claim is treated as an error in review.
- The plan never quotes more of a source than needed; it points.

## Plan placement and lifecycle

- Path: `docs/plans/<YYYY-MM-DD>-<service>-implementation-plan.md` in the implementation repo. This is the directory core's `/continue-plan` resumes from.
- Re-runs preserve completed todo state when ID + write scope are unchanged; everything else regenerates, and the chat report lists what changed.
- A plan with unresolved P0 ADR blockers is `Status: Blocked` — implementation sessions must not start P1 work that depends on a blocked P0.

## Fallback output contract

Used only when the architecture repo provides no `plan-service-implementation` skill. Frozen copy of the canonical structure — if the architecture repo's contract evolves, *its* version wins and this section is updated to match.

```markdown
# Implementation Agentic Plan: [Service Name]

## Status
[Draft | Ready for Review | Blocked]

## Scope
- service: / target repo: / target modules: / milestone: / non-goals:

## Source Inventory
| Source | Path / Evidence | What It Constrains | Confidence |

## Service Contract Summary
- ownership: / source of truth: / key APIs: / key events: /
  correctness-sensitive flows: / business invariants: / ADR constraints:

## Current Implementation State
- existing modules: / reusable code: / missing pieces: / implementation maturity:

## Blocking Decisions and Open Questions
| Blocker | Why It Blocks | Owner / Needed Input | Plan Impact |

## Agent Execution Rules
- preserve unrelated user changes / read referenced docs before editing /
  keep write scopes narrow / no secrets or runtime-only assumptions /
  update docs and indexes when required

## Ordered Implementation Todos
| ID | Priority | Agent Task | Inputs to Read | Write Scope | Acceptance Criteria | Verification | Dependencies | Executor |

## Test and Verification Matrix
| Area | Required Coverage | Evidence / Command | Owner |

## Rollout, Migration, and Operations
- migration sequence: / rollout guards: / rollback or compensation: /
  observability and runbooks: / release-readiness checks:

## Risks
| Risk | Impact | Mitigation | Trigger to Escalate |

## Definition of Done
- all source constraints traceable / all P0-P1 todos have acceptance criteria + verification /
  correctness-sensitive flows covered (idempotency, retry, replay, reconciliation, observability) /
  contract + migration changes have tests / docs, ADR follow-ups, release checks explicit
```

Priorities: `P0` blockers and correctness foundations · `P1` required implementation scope · `P2` pre-release hardening · `P3` post-milestone polish.

## Quality bar (applies under either contract)

- Definitive: concrete ordered tasks, not broad phases.
- Executable by another agent with zero hidden context.
- Write scopes disjoint enough for safe parallel agents.
- Verification present even when the planning session can't run the target's tests.
- Unverified implementation state stated honestly, never invented.
