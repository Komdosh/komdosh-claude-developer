# /adr-new [decision description]

Record a new within-service architectural decision. Checks if an ADR is actually warranted, then invokes adr-writer if so.

## Steps

- [ ] **Step 1: Get the decision description**

If the user provided a description, use it.
If not, ask: "What decision are you recording? Briefly describe what was chosen and what alternatives were considered."

- [ ] **Step 2: Check existing ADRs for overlap**

```bash
ls docs/adr/ 2>/dev/null | head -20
```

If an existing ADR covers this decision: "ADR <number> already covers this. No new ADR needed." Stop.

- [ ] **Step 3: Run check-adr-required skill**

Pass the decision description to `check-adr-required` skill.

If verdict is `NOT REQUIRED`: "This decision does not meet the threshold for an ADR. Proceeding without one."
If verdict is `REQUIRED` or `BORDERLINE`: continue to Step 4.

- [ ] **Step 4: Find the next ADR number**

```bash
ls docs/adr/ 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -1
```

If `docs/adr/` doesn't exist: `mkdir -p docs/adr` and start at 0001.

- [ ] **Step 5: Invoke adr-writer**

Pass to `adr-writer`:
- The decision description
- The next ADR number
- Any alternatives mentioned by the user

- [ ] **Step 6: Commit the ADR**

```bash
git add docs/adr/
git commit -m "docs: add ADR <number> — <decision-title>"
```

- [ ] **Step 7: Report**

State: ADR number, title, file path, status (Accepted).
