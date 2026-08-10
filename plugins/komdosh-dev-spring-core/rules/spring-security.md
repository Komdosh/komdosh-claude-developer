# Spring Security (WebFlux) Rules

How authentication and authorization are *written* in a service. Auditing what's already there is the `komdosh-dev-spring-quality` plugin's `/auth-audit`.

Before changing auth: read the existing `SecurityConfig` in `boot/` or `adapters/inbound/`, identify the auth model actually in use (JWT/OAuth2 resource server, session, API key, custom filter), and read the routes being protected. Choosing the auth *mechanism* is an architectural decision — that belongs in an ADR, not in a filter edit.

## Auth context must be extracted before any dispatcher switch

Reactor's `SecurityContext` is not propagated across `withContext`. Read the principal first, then switch:

```kotlin
suspend fun protectedOperation(): Result {
    // CORRECT: extract before withContext
    val auth = ReactiveSecurityContextHolder.getContext()
        .awaitSingle()
        .authentication
    val userId = UserId(auth.name)

    return withContext(Dispatchers.IO) {
        repository.findByUser(userId)   // use the extracted value
    }
}
```

Reading the security context *inside* `withContext` yields null or the wrong principal — an authorization bug that passes every happy-path test. See `rules/kotlin-coroutines.md`.

## 401 vs 403 are different answers

- **401 Unauthorized** — no valid credentials. `.authenticationEntryPoint(...)`.
- **403 Forbidden** — valid credentials, insufficient scope/role. `.accessDeniedHandler(...)`.

Both MUST return `application/problem+json`. The Spring defaults return an empty body; override them.

## The filter chain

```kotlin
@Bean
fun securityWebFilterChain(
    http: ServerHttpSecurity,
    objectMapper: ObjectMapper
): SecurityWebFilterChain =
    http
        .csrf { it.disable() }   // stateless bearer-token API; CSRF is session/cookie-bound
        .authorizeExchange { spec ->
            spec.pathMatchers("/actuator/health", "/actuator/info").permitAll()
            spec.pathMatchers(HttpMethod.POST, "/api/v1/admin/**").hasRole("ADMIN")
            spec.anyExchange().authenticated()      // deny-by-default, always last
        }
        .oauth2ResourceServer { it.jwt { } }
        .exceptionHandling {
            it.authenticationEntryPoint { exchange, _ ->
                writeProblem(exchange, HttpStatus.UNAUTHORIZED, "Authentication required", objectMapper)
            }
            it.accessDeniedHandler { exchange, _ ->
                writeProblem(exchange, HttpStatus.FORBIDDEN, "Insufficient privileges", objectMapper)
            }
        }
        .build()

private fun writeProblem(
    exchange: ServerWebExchange,
    status: HttpStatus,
    detail: String,
    objectMapper: ObjectMapper
): Mono<Void> {
    val problem = ProblemDetail.forStatusAndDetail(status, detail).apply {
        instance = exchange.request.uri
    }
    exchange.response.statusCode = status
    exchange.response.headers.contentType = MediaType.APPLICATION_PROBLEM_JSON
    val buffer = exchange.response.bufferFactory().wrap(objectMapper.writeValueAsBytes(problem))
    return exchange.response.writeWith(Mono.just(buffer))
}
```

Rules that hold regardless of the shape above:

- **`anyExchange().authenticated()` is always the last matcher** — deny by default. A route that falls through an incomplete matcher list is an unauthenticated endpoint nobody notices.
- **Order matters**: the first matching rule wins, so a broad `permitAll()` placed early silently shadows the specific rules after it.
- **CSRF disabled only for stateless bearer-token APIs.** Re-enable it for any cookie-authenticated path.
- Never call `setComplete()` with an empty body on 401/403 — see `rules/error-handling.md`.

## Every auth change ships with a test

At least one test asserting the 401 path and one asserting the 403 path. An auth change without a test proving the deny case is not done.
