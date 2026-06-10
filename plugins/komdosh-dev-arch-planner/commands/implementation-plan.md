---
description: Create a whole-service implementation agentic plan from the architecture repository — evidence inventory, ADR constraints, ordered agent todos with acceptance criteria and executors — written to docs/plans/.
argument-hint: <service-name> [--domain=<domain>] [--arch-repo=<path>] [--milestone=<milestone>]
---

Create an implementation agentic plan for the service named in `$ARGUMENTS`.

Invoke the `implementation-planner` agent with:

- **service** — the first positional argument (accept both `social-media-processor` and `social_media_processor` forms).
- **domain** — from `--domain=` if present.
- **arch_repo** — from `--arch-repo=` if present.
- **milestone** — from `--milestone=` if present; otherwise the planner takes the nearest milestone from the domain roadmap and says so.

If no service name was given, ask for one — do not guess. If the planner's discovery step cannot find the service's architecture package, relay its candidate list / redirect verbatim instead of improvising a plan.

The deliverable is `docs/plans/<YYYY-MM-DD>-<service>-implementation-plan.md` plus the chat summary (status, blockers, todo counts by priority, recommended next action).
