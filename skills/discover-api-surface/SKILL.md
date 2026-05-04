---
name: discover-api-surface
description: Resolve a Kotlin/Spring WebFlux service's HTTP surface into a normalised JSON IR (endpoints, schemas, auth, sample values). Tries OpenAPI file → Springdoc runtime if hinted → static controller parse, in that order. Use before generating QA artifacts (manual plan, Postman collection, QA console). Emits the IR to a temp path; do not commit it.
---

# Discover API Surface

## When to Use

Call this skill before any of `qa-plan-writer`, `qa-postman-writer`, or `qa-console-writer`. The IR it produces is the single source of truth those agents consume.

Run **once per session** when generating multiple artifacts back-to-back. The IR file path is reusable.

## Output

A JSON file at `.claude-tmp/api-surface.json` (relative to the service repo root). Schema:

```json
{
  "service":   { "name": "...", "basePackage": "...", "version": "..." },
  "auth":      { "scheme": "bearer-jwt" | "none", "tokenHeader": "Authorization" },
  "discoveredFrom": "openapi-file" | "openapi-runtime" | "static",
  "discoveredFromPath": "<file path or URL>",
  "environments": [
    { "name": "local", "baseUrl": "http://localhost:8080" }
  ],
  "endpoints": [
    {
      "id": "orders.create",
      "method": "POST",
      "path": "/api/v1/orders",
      "summary": "Create order",
      "resourceGroup": "orders",
      "request": {
        "headers":     [{ "name": "...", "required": true, "example": "..." }],
        "pathParams":  [{ "name": "...", "type": "uuid", "example": "..." }],
        "queryParams": [{ "name": "...", "type": "string", "required": false, "example": "..." }],
        "body":        { "schema": { /* JSON Schema subset */ }, "example": { /* deterministic */ } }
      },
      "responses": [
        { "status": 201, "contentType": "application/json", "schema": {}, "example": {} },
        { "status": 400, "contentType": "application/problem+json", "schema": {} }
      ]
    }
  ]
}
```

`resourceGroup` is the first path segment after the `/api/v<N>/` prefix. Used by all three writers as the grouping key so endpoints land in the same folder/section across artifacts.

## Steps

- [ ] **Step 1: Run `read-service-context` skill if not already run this session**

This produces the service name and base package needed to fill the IR `service` block.

- [ ] **Step 2: Try OpenAPI file (resolution order)**

Check, in order, the first match wins:

```bash
for f in openapi.yaml openapi.yml openapi.json \
         docs/openapi.yaml docs/openapi.yml docs/openapi.json \
         boot/build/generated/openapi/openapi.json; do
  [[ -f "$f" ]] && { echo "FOUND: $f"; break; }
done
```

If found: parse it. Set `discoveredFrom = "openapi-file"`, `discoveredFromPath = <path>`. Skip to Step 5.

- [ ] **Step 3: Try Springdoc runtime endpoint (only if hinted)**

Hints (any one is sufficient):
- `service.yaml` contains `localPort: <N>`
- the user passed `--running` to the calling command
- `lsof -nP -iTCP:8080 -sTCP:LISTEN` shows a listener (only as a tiebreaker; the user-provided hints take precedence)

If hinted, `curl -fsS http://localhost:<port>/v3/api-docs > /tmp/api-docs.json` then parse. Set `discoveredFrom = "openapi-runtime"`, `discoveredFromPath = "http://localhost:<port>/v3/api-docs"`. Skip to Step 5.

If the curl fails: do not block — fall through to Step 4 and note the failure in the final report.

- [ ] **Step 4: Static controller parse (fallback)**

Find controllers:

```bash
find . -path "*/adapters/inbound/*" -name "*Controller.kt" \
  -not -path "*/build/*" -not -path "*/generated/*" | sort
```

For each controller file, extract:
- Class-level `@RequestMapping("/...")` for the base path.
- Method-level `@GetMapping`/`@PostMapping`/`@PutMapping`/`@PatchMapping`/`@DeleteMapping` (with optional path).
- Method params: `@PathVariable`, `@RequestParam`, `@RequestBody`, `@RequestHeader`.
- `@ResponseStatus(HttpStatus.<X>)` overrides.
- Return type to identify the response DTO class name.
- `@Valid @RequestBody <DtoClass>` to identify the request DTO class name.

Then, for each referenced DTO class name, locate its declaration:

```bash
grep -rn "^data class <DtoClass>\b" --include='*.kt' .
```

Read the data-class primary constructor to extract field name + type + nullability. For nested types referenced by the DTO, repeat. Stop at primitive/standard library types.

For `@ExceptionHandler` mappings (look in any class annotated `@RestControllerAdvice` or `@ControllerAdvice`), record the exception → status code mapping. Use this to populate the `responses` error variants on every endpoint that propagates those exceptions (default: 400 if `ValidationException` is mapped, 404 if `EntityNotFoundException` is mapped, 409 if `ConflictException` is mapped, 500 always).

For the auth scheme, look for `SecurityWebFilterChain` configuration:

```bash
grep -rn "oauth2ResourceServer\|jwt()\|SecurityWebFilterChain" --include='*.kt' .
```

If found: `auth.scheme = "bearer-jwt"`, `auth.tokenHeader = "Authorization"`. Otherwise `auth.scheme = "none"`.

Set `discoveredFrom = "static"`. Continue to Step 5.

- [ ] **Step 5: Generate deterministic sample values**

For every field in every request body, path param, and query param, pick a sample by name+type using this table (apply the first matching rule):

| Field hint (case-insensitive substring) | Type | Sample value |
|---|---|---|
| `email` | string | `qa+test@example.com` |
| `id`, `Id`, `uuid` | UUID/string-uuid | `00000000-0000-4000-8000-00000000000<N>` (incrementing N per call site, capped at hex) |
| `name` | string | `"QA Test"` |
| `description` | string | `"QA test description"` |
| `phone` | string | `"+15555550100"` |
| `url` | string | `"https://example.com"` |
| `status`, enum | enum | first declared enum value |
| `amount`, `price`, `total`, `cents`, `Money` | number/long | `1000` |
| `quantity`, `count` | integer | `1` |
| `date`, `ZonedDateTime`, `Instant`, `OffsetDateTime` | string-datetime | `"2026-05-04T09:00:00Z"` |
| `LocalDate` | string-date | `"2026-05-04"` |
| any | boolean | `true` |
| any | array | one element constructed by the same rules |
| any | object | recurse |
| any | string | `"sample"` |

Re-running the skill must produce byte-identical samples for the same controller surface — no random values.

- [ ] **Step 6: Read environments from `service.yaml`**

```bash
[[ -f service.yaml ]] && grep -A3 "^environments:" service.yaml
```

Map each entry to `{name, baseUrl}`. If `service.yaml` is absent or has no `environments` key, default to:

```json
[
  {"name": "local",   "baseUrl": "http://localhost:8080"},
  {"name": "dev",     "baseUrl": "https://dev.example.com"},
  {"name": "staging", "baseUrl": "https://staging.example.com"}
]
```

- [ ] **Step 7: Write the IR**

```bash
mkdir -p .claude-tmp
```

Write the assembled JSON to `.claude-tmp/api-surface.json` with `jq` formatting if available, otherwise raw.

- [ ] **Step 8: Report**

State exactly:

```
API surface discovered.
  Source:    <openapi-file|openapi-runtime|static> (<path>)
  Endpoints: <N> across <M> resource groups (<list of groups>)
  Auth:      <bearer-jwt|none>
  IR path:   .claude-tmp/api-surface.json
```

If Step 4 ran and the static parse skipped anything (functional routes, custom argument resolvers it could not interpret), include a `Skipped:` line listing the file paths.

## Notes

- `.claude-tmp/` should be in the consumer service's `.gitignore`. If it isn't, the calling agent should add it before committing.
- The IR is intentionally ephemeral — regenerate on demand rather than stashing it long-term.
