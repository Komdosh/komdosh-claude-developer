---
description: Turn a feature description into a within-service implementation spec at docs/specs/, with data shapes, ports, edge cases, and an ordered task breakdown.
argument-hint: "[feature description]"
---

# /analyze-requirements

Written inline — the spec's value comes from this conversation's context. For a spec sourced from the architecture repository instead of free text, use `/implementation-plan` (`komdosh-dev-spring-delivery`).

1. `read-service-context`, then read the existing code in the affected area. **The spec must fit the service that exists, not a generic one.**
2. **System-level gate — stop if it trips.** If the feature needs a new event contract another service consumes, a change to a shared API contract, or a new infrastructure dependency, **stop and name the specific question for the user.** Do not design across the service boundary alone.
3. Write `docs/specs/<feature-slug>.md`:
   1. **Summary** — one paragraph from the user's perspective.
   2. **Scope** — what changes here, and what is explicitly *out* and why.
   3. **Data shapes** — domain entities, value classes, DTOs. Flag schema changes for `/add-migration`.
   4. **Ports** — new or modified interfaces in `application/ports/`.
   5. **Edge cases** — at least five, each with the expected behaviour and its API-layer status.
   6. **Task breakdown** — ordered, each naming the layer and the agent or command that executes it.
   7. **Open decisions** — run each through `check-adr-required`; anything `REQUIRED`/`BORDERLINE` needs `/adr-new` before implementation.
4. Print the commit commands; do not run them.

Present the spec and **wait for confirmation before implementing anything**.
