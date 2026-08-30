---
description: Generate QA artifacts — manual validation plan, Postman collection, and self-contained HTML console — from one shared API-surface discovery.
argument-hint: "[plan|postman|console|all]"
---

# /qa

Default target `all`.

| Target | Output |
|---|---|
| `plan` | `docs/qa/manual-validation-plan.md` — checklist; ticks preserved across regenerations |
| `postman` | `docs/qa/postman/` — v2.1 collection with `pm.test` assertions + per-env files |
| `console` | `docs/qa/qa-console.html` — one self-contained page, runs from `file://` |

1. `read-service-context`.
2. **`discover-api-surface` once** — the IR lands at `.claude-tmp/api-surface.json`. Three separate commands would rediscover the surface three times and could produce three artifacts describing three different snapshots of the same API.
   Empty surface → stop and say so. Three empty artifacts help nobody.
3. Ensure `.claude-tmp/` is gitignored — the IR is a build artifact.
4. Invoke the writers. For `all`, **send all three in one message so they run in parallel** — they write to disjoint paths, so there is no conflict.
5. Print the commit commands; do not run them.
6. Report each writer's output, the endpoint count, and the IR source (`file` / `runtime` / `static`) — plus how many ticks were preserved, the `newman run` command, and how to open the console (noting that a CORS error there is expected from `file://` and the page explains the fix).
