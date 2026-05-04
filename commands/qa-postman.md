# /qa-postman

Generate a Postman v2.1 collection with assertions and per-environment files. Newman-runnable. Output: `docs/qa/postman/`.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 2: Discover the API surface**

Run `discover-api-surface` skill.

- [ ] **Step 3: Ensure `.claude-tmp/` is gitignored**

```bash
grep -qxF '.claude-tmp/' .gitignore 2>/dev/null || echo '.claude-tmp/' >> .gitignore
```

- [ ] **Step 4: Invoke `qa-postman-writer`**

Pass the IR path. The agent overwrites collection + environment files under `docs/qa/postman/`.

- [ ] **Step 5: Suggest the commit (do not run it)**

Print, but do not execute:

```bash
git add docs/qa/postman/ .gitignore
git commit -m "docs(qa): regenerate Postman collection"
```

- [ ] **Step 6: Report**

Print the agent's report verbatim, plus a one-line note:

> "Run with `newman run …` (see report above). Install Newman: `npm i -g newman`."
