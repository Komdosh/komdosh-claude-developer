# Spring WebFlux

- **Every controller handler is a `suspend fun`.** Never return `Mono`/`Flux` from a controller.
- Controllers are adapter-layer only: deserialize → validate → delegate → serialize. Orchestration lives in `application/`.
- **Extract the auth principal, correlation ID, and trace context before any `withContext`** — see `rules/kotlin-coroutines.md` #8.
- Validate request bodies with `@Valid`; surface failures as `problem+json` (`rules/error-handling.md`), not Spring's default body.
