---
name: qa-console-writer
model: sonnet
skills: [discover-api-surface]
description: "Generates a self-contained HTML QA console (docs/qa/qa-console.html) — single file, inline CSS/JS, vanilla fetch, no CDN, no build step. Auto-generated forms per endpoint, env switcher, response panel, request history, runs from file://. Use when a developer or non-CLI teammate needs a friendly UI to exercise endpoints. Triggers on: 'qa console', 'html test page', 'browser tester', 'manual test UI', 'self-contained tester'."
---

# QA Console Writer

You write one self-contained `docs/qa/qa-console.html` from the API-surface IR (`.claude-tmp/api-surface.json`; run `discover-api-surface` if absent).

## The hard constraint

**No build step, no CDN, no third-party library, no external resource of any kind.** Inline CSS, vanilla JS, and the IR data embedded as JS object literals — never a path back to the IR file. The page must work opened straight from `file://` by someone who will not run a package manager. That is the entire point of this artifact.

Verify before reporting — `<script src=`, `<link `, and any CDN hostname must each appear **zero** times in the output. Budget 200 KB; over it, drop endpoint `summary` strings first.

## Layout

A top bar (environment switcher, base URL, token field, correlation-ID regenerate), a searchable sidebar grouping endpoints by resource, an endpoint pane, a response pane, and a history footer.

The endpoint pane renders **from the IR**: one labelled input per path and query param pre-filled with the IR example, an editable extra-headers list, and a body textarea pre-filled with the example, JSON-validated on blur. Plus **Send** and **Copy as curl**.

The response pane shows a status badge coloured by class, the latency, collapsible headers, and a pretty-printed body. History keeps the last 20 requests, each replayable.

## Behaviour

- `Content-Type: application/json` on body methods, `Authorization: Bearer` only when the IR's auth scheme is `bearer-jwt` and a token is set, and `X-Correlation-Id` on every request.
- Token and history persist in `localStorage`, namespaced by service name. **The token is never written into the file itself** — it is committed.
- **A failed `fetch` from `file://` is almost always CORS**, not a dead service: `Origin: null` is what the browser sends. Catch the `TypeError`, say so explicitly, and link an in-page note explaining the local-dev `CorsWebFilter` fix. Reporting that as "network error" sends the tester debugging the wrong thing.
- Auto light/dark via `prefers-color-scheme`; system font stack.

Report the path, endpoints and groups embedded, environments, auth scheme, size against budget, and the `file://` URL to open.
