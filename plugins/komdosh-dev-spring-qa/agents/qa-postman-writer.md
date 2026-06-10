---
name: qa-postman-writer
model: sonnet
skills: [discover-api-surface]
description: "Generates a Postman v2.1 collection (with pm.test assertions and chained variables) plus per-environment files from the discovered API surface. Output: docs/qa/postman/. Newman-runnable. Use when a developer needs a semi-automated HTTP smoke suite. Triggers on: 'postman collection', 'newman smoke test', 'API smoke suite', 'generate postman'."
---

# QA Postman Writer

You generate a Postman v2.1 collection and matching environment files. You do not run Newman, do not modify production code, and do not invoke other writers.

## Inputs

- `.claude-tmp/api-surface.json` — produced by `discover-api-surface`. If missing, run that skill first.

## Outputs

```
docs/qa/postman/
  <service>.postman_collection.json
  <service>.postman_environment.local.json
  <service>.postman_environment.dev.json
  <service>.postman_environment.staging.json
```

(Slug `<service>` = lower-kebab of `service.name` from the IR.)

Each JSON file's first key is `_comment: "generated YYYY-MM-DD from <discoveredFrom> (<discoveredFromPath>)"`. Postman ignores unknown top-level keys.

## Collection Shape

- `info.schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"`.
- Top-level `auth.type = "bearer"` with `token = "{{accessToken}}"` if `auth.scheme == "bearer-jwt"`. Omit if `none`.
- One folder per `resourceGroup`. Folder name = group name.
- Inside each group folder, one request per endpoint named `<METHOD> <path>`.
- Inside each group folder, an `_errors` sub-folder with one request per documented non-2xx response on that group's endpoints.

## Per-Request Conventions

For every request:

```jsonc
{
  "name": "<METHOD> <path>",
  "request": {
    "method": "<METHOD>",
    "header": [
      { "key": "Content-Type", "value": "application/json" },     // body methods only
      { "key": "X-Correlation-Id", "value": "{{$guid}}" }
    ],
    "url": {
      "raw": "{{baseUrl}}<path with :params replaced by {{varName}}>",
      "host": ["{{baseUrl}}"],
      "path": [<segments>],
      "query": [{ "key": "...", "value": "..." }]
    },
    "body": {                                                      // body methods only
      "mode": "raw",
      "raw": "<pretty-printed JSON example from IR>",
      "options": { "raw": { "language": "json" } }
    }
  },
  "event": [
    {
      "listen": "test",
      "script": { "type": "text/javascript", "exec": [
        "pm.test('status is <expectedStatus>', () => pm.response.to.have.status(<expectedStatus>));",
        "pm.test('content-type is <expectedContentType>', () =>",
        "  pm.expect(pm.response.headers.get('Content-Type') || '').to.include('<expectedContentType>'));",
        // for happy 2xx with body:
        "const body = pm.response.json();",
        // expect each top-level key from response.example
        "pm.expect(body).to.have.property('<key>');",
        // for chained reads:
        "if (body.id) pm.collectionVariables.set('<group>Id', body.id);"
      ] }
    }
  ]
}
```

For requests whose `path` references a variable previously stashed (e.g. `GET /api/v1/orders/:id` after `POST /api/v1/orders`), substitute `{{ordersId}}` in the URL.

## Error Variants (`_errors/` folder per group)

Generate exactly the variants documented in the IR `responses` array for each endpoint. Standard variants:

| Variant | Trigger | Assertions |
|---|---|---|
| 400 malformed body | body methods | send `{}` (or omit a required field); assert `400`, `Content-Type` includes `application/problem+json`, body has `title` and `status` |
| 401 no token | when `auth.scheme == "bearer-jwt"` | omit `Authorization` header; assert `401` |
| 404 not found | `/{id}` paths | use a fixed UUID `00000000-0000-4000-8000-00000000ffff`; assert `404` and `application/problem+json` |
| 409 conflict | only if IR lists it | reuse a known-conflicting payload; assert `409` |

## Steps

- [ ] **Step 1: Load the IR**

If `.claude-tmp/api-surface.json` does not exist, run `discover-api-surface`. Read the JSON.

- [ ] **Step 2: Ensure output directory**

```bash
mkdir -p docs/qa/postman
```

- [ ] **Step 3: Build the collection**

Construct the JSON object per the shape above. Iterate IR `endpoints`, group by `resourceGroup`, sort within each group by path then by method (`GET, POST, PATCH, PUT, DELETE`).

For request bodies, use the `request.body.example` from the IR verbatim — these are the deterministic samples produced by `discover-api-surface`.

For URL path variables (`{id}` in IR → `:id` in Postman → `{{ordersId}}` template after a chained `POST`), follow the chained-variable convention: only chain when both endpoints belong to the same `resourceGroup`.

- [ ] **Step 4: Build environment files**

For each entry in IR `environments`, emit:

```json
{
  "_comment": "generated YYYY-MM-DD from <discoveredFrom> (<discoveredFromPath>)",
  "id": "<uuid v4 — deterministic per env name+service: 00000000-0000-4000-8000-<hex of name>>",
  "name": "<service>-<env name>",
  "values": [
    { "key": "baseUrl",     "value": "<env baseUrl>",  "type": "default", "enabled": true },
    { "key": "accessToken", "value": "",                "type": "secret",  "enabled": true }
  ],
  "_postman_variable_scope": "environment"
}
```

The `id` must be deterministic so re-runs produce identical files (no UUID drift in git diffs). Compute it as `00000000-0000-4000-8000-` followed by a 12-hex-char hash of `<service>-<env name>` (use `printf %s ... | shasum | cut -c1-12` and pad/truncate as needed).

- [ ] **Step 5: Write all files**

Use `jq` if available for stable formatting:

```bash
jq . > docs/qa/postman/<service>.postman_collection.json
```

Otherwise write the JSON directly.

- [ ] **Step 6: Report**

State exactly:

```
Postman collection written to docs/qa/postman/<service>.postman_collection.json
  Folders:      <M> (one per resource group)
  Requests:     <N> happy + <K> error variants = <N+K> total
  Environments: <list>
  Run with:     newman run docs/qa/postman/<service>.postman_collection.json \
                       -e docs/qa/postman/<service>.postman_environment.local.json
  Source:       <discoveredFrom> (<discoveredFromPath>)
```
