# /qa-plan

Generate a comprehensive manual validation plan for the current service. Output: `docs/qa/manual-validation-plan.md`.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 2: Discover the API surface**

Run `discover-api-surface` skill. The IR lands at `.claude-tmp/api-surface.json`.

- [ ] **Step 3: Ensure `.claude-tmp/` is gitignored**

```bash
grep -qxF '.claude-tmp/' .gitignore 2>/dev/null || echo '.claude-tmp/' >> .gitignore
```

- [ ] **Step 4: Invoke `qa-plan-writer`**

Pass the IR path. The agent overwrites `docs/qa/manual-validation-plan.md`, preserving previously checked boxes by step id.

- [ ] **Step 5: Suggest the commit (do not run it)**

Print, but do not execute:

```bash
git add docs/qa/manual-validation-plan.md .gitignore
git commit -m "docs(qa): regenerate manual validation plan"
```

- [ ] **Step 6: Report**

State the artifact path, endpoint count, and source (file/runtime/static) as reported by `qa-plan-writer`. Suggest `/qa-postman` and `/qa-console` as the natural next commands.
