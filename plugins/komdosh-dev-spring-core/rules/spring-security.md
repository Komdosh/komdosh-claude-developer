# Spring Security (WebFlux)

How auth is *written*. Auditing what already exists is `komdosh-dev-spring-quality`'s `/auth-audit`.

Before changing auth: read the existing `SecurityConfig`, identify the auth model actually in use (JWT resource server, session, API key, custom filter), and read the routes being protected. Choosing the auth *mechanism* is an ADR-level decision, not a filter edit.

- **Extract the principal before any dispatcher switch** — `rules/kotlin-coroutines.md` #8. Reading the security context inside `withContext` yields null or the wrong principal, and passes every happy-path test.
- **`anyExchange().authenticated()` is always the last matcher.** First match wins, so a broad `permitAll()` placed early silently shadows every specific rule after it, and a route that falls off the end of an incomplete list is an unauthenticated endpoint nobody notices.
- **401 and 403 are different answers** — no credentials vs. valid credentials with insufficient scope. Both must return `application/problem+json`; override `authenticationEntryPoint` and `accessDeniedHandler`, because the Spring defaults return an empty body.
- CSRF is disabled **only** for stateless bearer-token APIs. Any cookie-authenticated path re-enables it.
- **Every auth change ships with a test asserting the deny case** — one 401, one 403. Without it the change is not done.
