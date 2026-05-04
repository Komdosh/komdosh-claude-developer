# API Conventions

## Route Shape

- Prefix: `/api/v<N>/<resource-plural>` (e.g., `/api/v1/orders`)
- Plural nouns for resources — `/orders`, not `/order`
- Use path parameters for resource identity: `/orders/{id}`
- Use query parameters for filtering/pagination: `/orders?status=PENDING&page=0`

## HTTP Semantics

| Operation | Method | Success status | Notes |
|---|---|---|---|
| Create | POST | 201 Created | Include `Location: /api/v1/orders/{id}` header |
| Read one | GET | 200 OK | 404 if not found |
| Read many | GET | 200 OK | Empty array (not 404) if no results |
| Replace | PUT | 200 OK or 204 No Content | |
| Partial update | PATCH | 200 OK or 204 No Content | |
| Delete | DELETE | 204 No Content | 404 if not found |

## Response Types

- Success: resource DTO or `{ "items": [...], "total": N }` for collections.
- Errors: `application/problem+json` (RFC 9457) — see `rules/error-handling.md`.
- Never expose `domain/` entity objects directly as response bodies.
- Never expose persistence IDs, stack traces, or internal implementation details.

## DTO Placement

- Request DTOs: `adapters/inbound/<resource>/dto/`
- Response DTOs: `adapters/inbound/<resource>/dto/`
- Shared contract types (consumed by other services): `api/`
- Never reuse the same class for both request and response.

## Versioning

- Version in URI path: `/v1/`, `/v2/`
- Non-breaking additions (new optional fields) are allowed within a version.
- Breaking changes (removed fields, changed semantics) require a new version.
- Deprecate before removing: serve both `/v1/` and `/v2/` during transition.
