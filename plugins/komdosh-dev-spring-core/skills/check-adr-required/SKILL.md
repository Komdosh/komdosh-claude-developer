---
name: check-adr-required
description: Use when a within-service architectural decision (storage technology, significant internal pattern, caching layer, DI approach, library selection) is being made and it is unclear if it warrants an ADR. Returns REQUIRED, NOT REQUIRED, or BORDERLINE with rationale.
---

# Check ADR Required

State the decision in one sentence, then check `docs/adr/` — if an existing ADR already covers it, return NOT REQUIRED and cite it.

**REQUIRED** when all three hold:

1. Hard to reverse — changing it later touches multiple modules or needs a data migration.
2. At least two reasonable alternatives existed; the choice was not obvious.
3. Within this service's boundary, not cross-service or platform-level.

**NOT REQUIRED** for the obvious default, an easily reversible choice, a purely stylistic one, or anything already documented.

**BORDERLINE** when 1 and 2 hold but the scope is narrow — recommend `/adr-new`, don't block.

Return exactly `REQUIRED` / `NOT REQUIRED` / `BORDERLINE: <rationale>`. On the first two, the ADR lands at `docs/adr/NNNN-<slug>.md` **before** implementation begins.
