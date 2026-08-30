# API Conventions

- Routes: `/api/v<N>/<resource-plural>`, path params for identity, query params for filtering.
- Errors: `application/problem+json` (RFC 9457) — `rules/error-handling.md`.
- **Never expose a `domain/` entity, a persistence ID, or an internal implementation detail in a response body.** Map to a DTO.
- Request and response DTOs are separate classes, in `adapters/inbound/<resource>/dto/`. Types other services consume go in `api/`.
- Versioning is in the URI path. Adding an optional field is non-breaking; removing one or changing semantics needs a new version served alongside the old.

Standard REST/HTTP status semantics apply — no local deviations.
