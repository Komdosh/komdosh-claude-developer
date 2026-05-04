---
name: check-adr-required
description: Use when a within-service architectural decision (storage technology, significant internal pattern, caching layer, DI approach, library selection) is being made and it is unclear if it warrants an ADR. Returns REQUIRED, NOT REQUIRED, or BORDERLINE with rationale.
---

# Check ADR Required

## When to Use

Call this skill before beginning implementation when a non-trivial decision has been made that could affect the long-term shape of the service. Examples that commonly warrant an ADR:
- Choosing a caching strategy (in-memory vs Redis vs none)
- Selecting a new library for a significant concern (auth, serialization, metrics)
- Picking a persistence pattern (outbox vs direct publish, jOOQ vs Exposed)
- Adopting an internal architectural pattern (CQRS, event sourcing within the service)

## Decision Criteria

An ADR is **REQUIRED** when ALL three are true:
1. The decision is hard to reverse (changing it later would touch multiple modules or require a data migration).
2. There were at least 2 reasonable alternatives (the choice was not obvious).
3. The decision is within this service's boundary (not a cross-service or platform-level decision).

An ADR is **NOT REQUIRED** when:
- The choice is the obvious default (e.g., "use a standard Spring bean for this service").
- The change is easily reversible with no migration cost.
- The decision is purely cosmetic/stylistic (covered by code-style rules).
- It is already documented elsewhere (existing ADR, spec doc, CLAUDE.md).

**BORDERLINE**: criteria 1 and 2 are true but the scope is narrow (e.g., adding one small library for a focused use case). Recommend an ADR but do not block.

## Steps

- [ ] **Step 1: State the decision in one sentence**

Write: "The decision is: [describe what was chosen]."

- [ ] **Step 2: Check existing ADRs for overlap**

```bash
ls docs/adr/ 2>/dev/null | head -20
```

If an existing ADR covers this decision, reference it and return NOT REQUIRED.

- [ ] **Step 3: Apply the three criteria**

Score each criterion: YES / NO / PARTIAL.

- [ ] **Step 4: Return verdict**

Return exactly one of:
- `REQUIRED` — proceed to `adr-writer` before writing code.
- `NOT REQUIRED` — proceed directly to implementation.
- `BORDERLINE: <one sentence rationale>` — recommend `adr-writer` but do not block.

## Important

If `REQUIRED` or `BORDERLINE`: remind the calling agent to invoke `adr-writer` and save the ADR to `docs/adr/NNNN-<slug>.md` before beginning implementation.
