# /qa-console

Generate a self-contained HTML QA console for the current service. Output: `docs/qa/qa-console.html`. Open in a browser, no server required.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 2: Discover the API surface**

Run `discover-api-surface` skill.

- [ ] **Step 3: Ensure `.claude-tmp/` is gitignored**

```bash
grep -qxF '.claude-tmp/' .gitignore 2>/dev/null || echo '.claude-tmp/' >> .gitignore
```

- [ ] **Step 4: Invoke `qa-console-writer`**

Pass the IR path. The agent overwrites `docs/qa/qa-console.html`.

- [ ] **Step 5: Suggest the commit (do not run it)**

Print, but do not execute:

```bash
git add docs/qa/qa-console.html .gitignore
git commit -m "docs(qa): regenerate self-contained QA console"
```

- [ ] **Step 6: Report**

Print the agent's report verbatim, plus:

> "Open with `open docs/qa/qa-console.html` (macOS) or `xdg-open` (Linux). If you hit a CORS error, see the `#cors-help` section in the page footer."
