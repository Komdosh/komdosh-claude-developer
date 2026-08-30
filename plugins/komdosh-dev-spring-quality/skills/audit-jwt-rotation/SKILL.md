---
name: audit-jwt-rotation
user-invocable: false
description: "Audits JWT/JWK plumbing for Spring Security OAuth2 resource server: ReactiveJwtDecoder presence, algorithm allowlist (no `none`, no symmetric in asymmetric contexts), JWK source refresh policy, issuer + audience validation, expiration enforcement, no production keys in test fixtures. Read-only — never extracts the actual key material, only checks configuration shape."
---

# Audit JWT Rotation

Applies only where the project decodes JWTs. **No resource-server starter and no Nimbus usage → return `applicable: false` and stop.** N/A is the correct outcome, not a BLOCKER.

Confirms configuration **shape** only. **Never read, print, or transmit** a key, passphrase, or any `*_SECRET_*`/`*_KEY_*`/`*_TOKEN_*`/`*_PASSWORD_*` value; never run a task that loads runtime credentials; never fetch a remote JWK Set — that is runtime behaviour, not static audit.

## Decoder shape

Find the configuration (Java-style `@Bean fun jwtDecoder`, Kotlin DSL `oauth2ResourceServer { jwt { … } }`, or Spring Boot's `spring.security.oauth2.resourceserver.jwt.issuer-uri` autoconfig) and record which it is: **JwkSetUri** (most common) · **PublicKey** (static) · **SecretKey** (symmetric, rare and notable) · **issuer-location** (auto-discovers the JWK Set URI).

## Checks

**Algorithms** — record the explicit allowlist, or note that default Nimbus resolution is in use (normally safe, still worth surfacing).

- `none` anywhere in an allowlist → **BLOCKER**.
- Asymmetric `RS*`/`ES*` **and** symmetric `HS*` in the same allowlist → **WARNING**, algorithm-confusion surface.
- Only `HS*` alongside a JWK Set URI → **BLOCKER** — a JWK Set serves asymmetric keys; symmetric expects a shared secret, so this configuration cannot be what was intended.

**JWK refresh** — a JwkSetUri decoder refreshes on an unknown `kid`, which covers ordinary rotation. A **static PublicKey decoder has no such path**: without a documented rotation procedure (a `// ROTATION:` note or an ADR), that is a WARNING.

**Validators** — Spring's default validates `exp` and `nbf` only.

- No issuer validation with more than one `issuer-uri` in the config → **BLOCKER**.
- No audience validation in a service expecting audience-scoped tokens → **BLOCKER**. A token signed by the right key but issued for another audience is otherwise accepted.
- A custom validator that replaces rather than delegates to `JwtValidators.createDefault()`, dropping the `exp` check → **BLOCKER**.

Single issuer using only the default → no finding.

**Test fixtures** — a test config referencing a production-shaped key env var, or a hard-coded real-looking key block, is a **WARNING**. Report the reference; never the value.

## Emit

JSON: `applicable`, a per-decoder record (`file:line`, shape, issuer, algorithms, issuer/audience/exp flags, findings), and `test_fixture_findings`.

Where a gateway validates tokens upstream and passes identity downstream as a header, classify "no JWT decoder needed" as INFO — that is a gateway-level audit, out of scope here.
