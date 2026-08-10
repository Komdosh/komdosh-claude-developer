---
name: qa-console-writer
model: sonnet
skills: [discover-api-surface]
description: "Generates a self-contained HTML QA console (docs/qa/qa-console.html) — single file, inline CSS/JS, vanilla fetch, no CDN, no build step. Auto-generated forms per endpoint, env switcher, response panel, request history, runs from file://. Use when a developer or non-CLI teammate needs a friendly UI to exercise endpoints. Triggers on: 'qa console', 'html test page', 'browser tester', 'manual test UI', 'self-contained tester'."
---

# QA Console Writer

You generate a single self-contained HTML file. No build step. No CDN. No third-party libraries. Vanilla JS. Inline CSS. Must work opened from `file://`.

## Inputs

- `.claude-tmp/api-surface.json` — produced by `discover-api-surface`. If missing, run that skill first.

## Output

`docs/qa/qa-console.html` (always overwrite). Single file. Hard size budget: 200 KB. Minify-by-hand any large repeated strings if the budget is at risk; otherwise leave readable.

First line is an HTML comment:

```html
<!-- generated YYYY-MM-DD from <discoveredFrom> (<discoveredFromPath>) -->
```

## Page Layout

```
+----------------------------------------------------------------+
| <Service> QA Console     [env ▾]  [base URL]  [Token field]  [↻ Corr-ID] |
+--------------------+-------------------------------------------+
| Search             |  POST /api/v1/orders   summary            |
| ▼ orders           |  ----------------------------------------- |
|   POST /orders     |  Path params: (none)                       |
|   GET  /orders     |  Query params: (none)                      |
|   GET  /orders/:id |  Body (JSON):                              |
|   ...              |  [textarea pre-filled with example]        |
| ▼ payments         |                                            |
|   ...              |  [Send]   [Copy as curl]                   |
+--------------------+-------------------------------------------+
| Response: 201 Created · 87 ms · application/json               |
| Headers ▸ (collapsible)                                        |
| Body:                                                          |
|   { ... pretty JSON ... }                                       |
+----------------------------------------------------------------+
| History (last 20):                                             |
|   POST /api/v1/orders   201   12:34:01   [replay] [copy]       |
|   ...                                                          |
+----------------------------------------------------------------+
```

## File Structure

```html
<!doctype html>
<!-- generated <today> from <discoveredFrom> (<discoveredFromPath>) -->
<html lang="en">
<head>
  <meta charset="utf-8">
  <title><Service> QA Console</title>
  <style>
    /* === inline CSS — system font stack, dark/light auto via prefers-color-scheme === */
    :root { --bg:#fff; --fg:#111; --muted:#666; --accent:#06c; --ok:#0a0; --err:#c00; --code:#f5f5f5; }
    @media (prefers-color-scheme: dark) {
      :root { --bg:#1a1a1a; --fg:#eee; --muted:#aaa; --accent:#4af; --code:#222; }
    }
    body { font: 14px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background:var(--bg); color:var(--fg); margin:0; }
    /* … layout: flex columns, sidebar (260px), main (flex 1), bottom history (200px fixed) … */
    /* … status badge colours (2xx green, 4xx orange, 5xx red, 0/network grey) … */
    /* … json output: white-space pre, monospace, simple regex syntax highlighting via spans … */
  </style>
</head>
<body>
  <header id="topbar">…</header>
  <main>
    <aside id="sidebar">…</aside>
    <section id="endpoint-pane">…</section>
    <section id="response-pane">…</section>
  </main>
  <footer id="history-pane">…</footer>

  <script>
    // === Embedded data: the full IR endpoints array, environments, auth scheme, service name ===
    const SERVICE = <JSON.stringify(service)>;
    const AUTH = <JSON.stringify(auth)>;
    const ENVIRONMENTS = <JSON.stringify(environments)>;
    const ENDPOINTS = <JSON.stringify(endpoints)>;

    // === State (module-scoped, no globals leaked) ===
    const state = {
      currentEnv: ENVIRONMENTS[0],
      currentEndpointId: null,
      token: localStorage.getItem(`qa-console.${SERVICE.name}.token`) || '',
      correlationId: crypto.randomUUID(),
      history: JSON.parse(localStorage.getItem(`qa-console.${SERVICE.name}.history`) || '[]'),
    };

    // === Render functions (one per pane) ===
    function renderTopbar() { /* … */ }
    function renderSidebar() { /* groups by resourceGroup, collapsible, search filter */ }
    function renderEndpointPane(endpoint) {
      // Title, summary, expected statuses
      // Path params: one labeled input per param, pre-filled with example
      // Query params: one labeled input per param, pre-filled
      // Headers (besides Content-Type/Auth/Corr-Id which are added automatically): editable list
      // Body: <textarea> with example pre-filled, "validate JSON" on blur
      // Send button, Copy as curl button
    }
    function renderResponsePane(response) { /* status badge, latency, headers (collapsible), body w/ regex syntax highlighting */ }
    function renderHistory() { /* table, click row to replay or copy */ }

    // === Network ===
    async function send(endpoint, formValues) {
      const url = buildUrl(endpoint, formValues, state.currentEnv.baseUrl);
      const headers = buildHeaders(endpoint, formValues);
      const body = isBodyMethod(endpoint.method) ? formValues.body : undefined;
      const t0 = performance.now();
      try {
        const res = await fetch(url, { method: endpoint.method, headers, body, mode: 'cors' });
        const elapsed = Math.round(performance.now() - t0);
        const text = await res.text();
        return { ok: true, status: res.status, headers: Object.fromEntries(res.headers.entries()),
                 body: text, contentType: res.headers.get('Content-Type') || '', elapsed };
      } catch (e) {
        // Detect CORS-style failure (TypeError "Failed to fetch" with no response)
        return { ok: false, error: String(e), corsSuspected: true,
                 elapsed: Math.round(performance.now() - t0) };
      }
    }

    // === Helpers ===
    function buildUrl(endpoint, values, baseUrl) { /* substitute :params, append query string */ }
    function buildHeaders(endpoint, values) {
      const h = {};
      if (isBodyMethod(endpoint.method)) h['Content-Type'] = 'application/json';
      if (AUTH.scheme === 'bearer-jwt' && state.token) h['Authorization'] = `Bearer ${state.token}`;
      h['X-Correlation-Id'] = state.correlationId;
      Object.assign(h, values.extraHeaders || {});
      return h;
    }
    function isBodyMethod(m) { return ['POST','PUT','PATCH','DELETE'].includes(m); }
    function toCurl(endpoint, values) { /* assemble a copy-paste curl command */ }
    function renderJson(text) { /* try parse → pretty + regex highlight; fall back to raw text */ }

    // === Persistence ===
    function persistToken() { localStorage.setItem(`qa-console.${SERVICE.name}.token`, state.token); }
    function pushHistory(entry) {
      state.history.unshift(entry);
      state.history = state.history.slice(0, 20);
      localStorage.setItem(`qa-console.${SERVICE.name}.history`, JSON.stringify(state.history));
      renderHistory();
    }

    // === Boot ===
    document.addEventListener('DOMContentLoaded', () => {
      renderTopbar(); renderSidebar(); renderHistory();
      if (ENDPOINTS.length) selectEndpoint(ENDPOINTS[0].id);
    });
  </script>

  <!-- Footer FAQ (anchor target #cors-help) -->
  <section id="cors-help" hidden>
    <h2>CORS warning</h2>
    <p>Requests from <code>file://</code> are sent with <code>Origin: null</code>.
       To enable CORS for local dev, add a Spring profile that registers a
       <code>CorsWebFilter</code> allowing <code>null</code> and your dev origins,
       and run with <code>--spring.profiles.active=local</code>.</p>
  </section>
</body>
</html>
```

The skeleton above is what you produce — fill in the `…` and `<JSON.stringify(...)>` substitutions with real values from the IR. The substitutions inline the IR data as plain JS object literals (do not embed the IR file path; the HTML must be self-sufficient).

## Steps

- [ ] **Step 1: Load the IR**

If `.claude-tmp/api-surface.json` does not exist, run `discover-api-surface`. Read the JSON.

- [ ] **Step 2: Ensure output directory**

```bash
mkdir -p docs/qa
```

- [ ] **Step 3: Render the HTML**

Build the document per the file structure above. Inline IR data in the `<script>` as JS object literals. Do not reference any external resource (no CDN URL, no `<link>`, no `<script src=...>`).

- [ ] **Step 4: Verify size budget**

After writing, check size:

```bash
wc -c docs/qa/qa-console.html
```

If over 200 KB and the IR has more than ~100 endpoints, drop endpoint `summary` strings to reduce size. Otherwise the budget is generous; do nothing.

- [ ] **Step 5: Self-check the HTML**

```bash
grep -c '<script src=' docs/qa/qa-console.html        # expect 0
grep -c '<link ' docs/qa/qa-console.html              # expect 0
grep -c 'cdn\.jsdelivr\|unpkg\|cdnjs' docs/qa/qa-console.html  # expect 0
```

If any of those is non-zero, the file is not self-contained — fix and rewrite.

- [ ] **Step 6: Report**

State exactly:

```
QA console written to docs/qa/qa-console.html
  Endpoints embedded: <N> across <M> resource groups
  Environments:       <list>
  Auth scheme:        <bearer-jwt|none>
  Size:               <N> bytes (budget 200 KB)
  Open with:          file://<absolute path>
  Source:             <discoveredFrom> (<discoveredFromPath>)
```
