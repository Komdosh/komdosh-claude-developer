# /qa [plan|postman|console|all]

Generate QA artifacts for the current service from one discovered API surface. Default target: `all`.

| Target | Output | Writer |
|---|---|---|
| `plan` | `docs/qa/manual-validation-plan.md` — markdown checklist, checked boxes preserved across regenerations | `qa-plan-writer` |
| `postman` | `docs/qa/postman/` — v2.1 collection with `pm.test` assertions + per-env files, Newman-runnable | `qa-postman-writer` |
| `console` | `docs/qa/qa-console.html` — single self-contained page, no CDN, runs from `file://` | `qa-console-writer` |
| `all` | all three | all three, in parallel |

The three writers share one `discover-api-surface` pass. Running them as three separate commands would rediscover the surface three times and risk three artifacts describing three different snapshots of the API.

## Steps

- [ ] **Step 1: Load service context**

Run the `read-service-context` skill if it has not run this session.

- [ ] **Step 2: Discover the API surface — once**

Run the `discover-api-surface` skill. The IR lands at `.claude-tmp/api-surface.json` (OpenAPI file → Springdoc runtime → static controller parse, in that order).

If the surface is empty, stop and say so — the service has no HTTP endpoints to exercise, and three empty artifacts help nobody.

- [ ] **Step 3: Ensure `.claude-tmp/` is gitignored**

```bash
grep -qxF '.claude-tmp/' .gitignore 2>/dev/null || echo '.claude-tmp/' >> .gitignore
```

The IR is a build artifact; it never gets committed.

- [ ] **Step 4: Invoke the writer(s)**

Pass the IR path to each requested writer. For `all`, invoke all three **in one message so they run in parallel** — they write to disjoint paths (`manual-validation-plan.md`, `postman/`, `qa-console.html`), so there is no write conflict.

- [ ] **Step 5: Suggest the commit (do not run it)**

Print, but do not execute:

```bash
git add docs/qa/ .gitignore
git commit -m "docs(qa): regenerate QA artifacts"
```

- [ ] **Step 6: Report**

Print each writer's report verbatim, then the endpoint count and the IR source (`file` / `runtime` / `static`), plus whichever of these apply:

- `plan` — "Checked boxes preserved: N."
- `postman` — "Run with `newman run docs/qa/postman/<service>.postman_collection.json -e <env>.json` (`npm i -g newman`)."
- `console` — "Open with `open docs/qa/qa-console.html` (macOS) or `xdg-open` (Linux). On a CORS error, see the `#cors-help` section in the page footer."
