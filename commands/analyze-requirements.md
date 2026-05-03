# /analyze-requirements [feature description]

Analyze a feature description and produce a within-service implementation spec. Invokes `requirements-analyst`, checks for ADR needs, and saves the spec to `docs/specs/`.

## Steps

- [ ] **Step 1: Get the feature description**

If the user provided a description after `/analyze-requirements`, use it.
If not, ask: "Please describe the feature you want to implement."

- [ ] **Step 2: Load service context**

Run `read-service-context` skill to orient the analyst.

- [ ] **Step 3: Invoke requirements-analyst**

Pass to `requirements-analyst`:
- The feature description
- The service context (name, package, modules)
- Any relevant existing code that was found

- [ ] **Step 4: Check for ADR-required decisions**

For each "Open Decision" flagged by `requirements-analyst`, invoke `check-adr-required` skill.
If any decision returns `REQUIRED` or `BORDERLINE`: "This decision may need an ADR. Invoke `/adr-new` before beginning implementation."

- [ ] **Step 5: Save the spec**

```bash
mkdir -p docs/specs
```

Save the spec output to `docs/specs/<feature-slug>.md`.

```bash
git add docs/specs/<feature-slug>.md
git commit -m "docs: add implementation spec for <feature>"
```

- [ ] **Step 6: Present and confirm**

Present the spec to the user.
Ask: "Does this spec look correct? Should I proceed to create an implementation plan, or do you want to make changes first?"

Do not begin implementation until the user confirms.
