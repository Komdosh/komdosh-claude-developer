---
name: discover-api-surface
user-invocable: false
description: Resolve a Kotlin/Spring WebFlux service's HTTP surface into a normalised JSON IR (endpoints, schemas, auth, sample values). Tries OpenAPI file → Springdoc runtime if hinted → static controller parse, in that order. Use before generating QA artifacts (manual plan, Postman collection, QA console). Emits the IR to a temp path; do not commit it.
---

# Discover API Surface

The single source of truth all three QA writers consume. **Run once per session** — the IR path is reusable, and re-discovering per writer risks three artifacts describing three different snapshots.

## IR — `.claude-tmp/api-surface.json`

```json
{
  "service": { "name": "…", "basePackage": "…", "version": "…" },
  "auth":    { "scheme": "bearer-jwt" | "none", "tokenHeader": "Authorization" },
  "discoveredFrom": "openapi-file" | "openapi-runtime" | "static",
  "discoveredFromPath": "…",
  "environments": [{ "name": "local", "baseUrl": "http://localhost:8080" }],
  "endpoints": [{
    "id": "orders.create", "method": "POST", "path": "/api/v1/orders",
    "summary": "…", "resourceGroup": "orders",
    "request":   { "headers": [], "pathParams": [], "queryParams": [], "body": { "schema": {}, "example": {} } },
    "responses": [{ "status": 201, "contentType": "application/json", "schema": {}, "example": {} }]
  }]
}
```

`resourceGroup` is the first path segment after `/api/v<N>/` — **all three writers group by it**, so endpoints land in matching sections across artifacts.

## Resolution order — first match wins

1. **OpenAPI file** — `openapi.{yaml,yml,json}`, then `docs/`, then `boot/build/generated/openapi/`.
2. **Springdoc runtime**, only when hinted — `localPort` in `service.yaml`, an explicit `--running`, or a listener on the port as a tiebreaker. A failed curl **falls through rather than blocking**, and the failure is noted in the report.
3. **Static controller parse** of `*Controller.kt` under `adapters/inbound/`.

## Static parse

Per controller: class-level `@RequestMapping` base path · the method mapping annotations and their paths · `@PathVariable`/`@RequestParam`/`@RequestBody`/`@RequestHeader` params · `@ResponseStatus` overrides · the request and response DTO class names.

Then resolve each DTO by locating its `data class` declaration and reading the primary constructor for field name, type, and nullability — recursing into nested types, stopping at standard-library ones.

**Error responses come from the `@RestControllerAdvice` handlers**, mapping exception → status, applied to every endpoint that can propagate them (500 always). Auth scheme comes from the presence of `oauth2ResourceServer`/`SecurityWebFilterChain`.

Report anything the parse couldn't interpret — functional routes, custom argument resolvers — as an explicit `Skipped:` list. **Silent omission reads as full coverage.**

## Sample values must be deterministic

Same surface → byte-identical samples, so a regeneration produces no diff noise. Never random. First matching rule wins:

| Field name contains | Sample |
|---|---|
| `email` | `qa+test@example.com` |
| `id` / `uuid` | `00000000-0000-4000-8000-00000000000<N>`, N incrementing per call site |
| `name` / `description` | `"QA Test"` / `"QA test description"` |
| `phone` / `url` | `"+15555550100"` / `"https://example.com"` |
| enum / `status` | the first declared symbol |
| `amount`/`price`/`total`/money | `1000` |
| `quantity`/`count` | `1` |
| instant / datetime | `"2026-05-04T09:00:00Z"` |
| date | `"2026-05-04"` |
| — boolean / array / object / string | `true` / one element by these rules / recurse / `"sample"` |

## Environments

From `service.yaml`'s `environments` key, else default `local` / `dev` / `staging`.

## Report

Source and path · endpoint count across N groups (named) · auth scheme · IR path · anything skipped.

The IR is ephemeral — `.claude-tmp/` belongs in the consumer's `.gitignore`; regenerate rather than stash it.
