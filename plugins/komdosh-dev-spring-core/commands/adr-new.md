# /adr-new [decision description]

Record a within-service architectural decision as a durable ADR in `docs/adr/`. Checks that an ADR is actually warranted, then writes it inline — no subagent, because the work is one templated file and a subagent would only lose the conversation context that holds the actual rationale.

## Steps

- [ ] **Step 1: Get the decision description**

If the user provided one, use it. Otherwise ask: "What decision are you recording? Briefly describe what was chosen and what alternatives were considered."

- [ ] **Step 2: Check existing ADRs for overlap**

```bash
ls docs/adr/ 2>/dev/null | head -20
```

If an existing ADR already covers this decision: "ADR `<number>` already covers this. No new ADR needed." Stop.

- [ ] **Step 3: Run the `check-adr-required` skill**

Pass the decision description.

- `NOT REQUIRED` → "This decision does not meet the threshold for an ADR. Proceeding without one." Stop.
- `REQUIRED` or `BORDERLINE` → continue.

An ADR is warranted when the decision is hard to reverse, there were at least two reasonable alternatives, and it sits inside this service's boundary.

- [ ] **Step 4: Find the next ADR number**

```bash
ls docs/adr/ 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -1
```

Increment by 1. If `docs/adr/` doesn't exist: `mkdir -p docs/adr` and start at `0001`.

- [ ] **Step 5: Write `docs/adr/NNNN-<decision-slug>.md`**

The slug is lowercase and hyphenated and names the *decision*, not the outcome — `0001-use-jooq-for-persistence.md`, `0002-coroutine-safe-transaction-pattern.md`.

Use this template exactly:

```markdown
# NNNN: <Decision Title>

**Date**: YYYY-MM-DD
**Status**: Accepted

## Context

<Why does this decision need to be made? What constraints, requirements, or events led here?>

## Decision

<What was decided? Be specific — name the technology, pattern, or approach.>

## Consequences

### Positive
- <Benefit 1>
- <Benefit 2>

### Negative / Trade-offs
- <Trade-off 1>
- <Risk 1>

## Alternatives Considered

### Alternative A: <Name>
<Why it was rejected, in one or two sentences.>

### Alternative B: <Name>
<Why it was rejected, in one or two sentences.>
```

Record only what was actually decided and actually considered. An invented alternative is worse than a short ADR — someone will later treat it as evidence the option was evaluated.

- [ ] **Step 6: Suggest the commit (do not run it)**

Print, but do not execute:

```bash
git add docs/adr/<file>
git commit -m "docs: add ADR <number> — <decision-title>"
```

- [ ] **Step 7: Report**

State the ADR number, title, file path, status, and that the commit was suggested but not executed.
