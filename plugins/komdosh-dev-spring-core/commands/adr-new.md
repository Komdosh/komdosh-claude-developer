---
description: Record a within-service architectural decision as an ADR in docs/adr/, after confirming one is actually warranted.
argument-hint: "[decision description]"
---

# /adr-new

Written inline, no subagent — the rationale lives in this conversation, and a subagent would not have it.

1. Check `docs/adr/` for overlap. If an existing ADR covers it, cite it and stop.
2. Run `check-adr-required`. `NOT REQUIRED` → say so and stop. `REQUIRED`/`BORDERLINE` → continue.
3. Next number from `docs/adr/`, starting at `0001`. Slug names the **decision**, not the outcome: `0001-use-jooq-for-persistence.md`.
4. Write it:

```markdown
# NNNN: <Decision Title>

**Date**: YYYY-MM-DD
**Status**: Accepted

## Context
<What forced this decision — constraints, requirements, the triggering event.>

## Decision
<What was decided. Name the technology, pattern, or approach specifically.>

## Consequences
### Positive
### Negative / Trade-offs

## Alternatives Considered
### <Name> — <why it was rejected, in one or two sentences>
```

**Record only what was actually decided and actually considered.** An invented alternative is worse than a short ADR — someone will later read it as evidence that option was evaluated.

5. Print the `git add`/`git commit` commands; **do not run them**.
