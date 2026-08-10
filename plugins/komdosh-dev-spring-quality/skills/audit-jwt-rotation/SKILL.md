---
name: audit-jwt-rotation
user-invocable: false
description: "Audits JWT/JWK plumbing for Spring Security OAuth2 resource server: ReactiveJwtDecoder presence, algorithm allowlist (no `none`, no symmetric in asymmetric contexts), JWK source refresh policy, issuer + audience validation, expiration enforcement, no production keys in test fixtures. Read-only — never extracts the actual key material, only checks configuration shape."
---

# Audit JWT Rotation

## When to Use

Run this skill from `/jwt-rotation` or as part of `/security-audit`. It applies only to projects that use `spring-boot-starter-oauth2-resource-server` (or equivalent Spring Security OAuth2 / JWT decoding). On projects without it, the skill returns `applicable: false` and exits cleanly — N/A is the correct outcome, not a BLOCKER.

Read-only. The skill confirms configuration **shape**; it never reads, prints, or transmits private keys, passphrases, or symmetric secrets.

## Do NOT

- Print or log JWK content, signing keys, GPG passphrases, or any environment variable starting with `*_SECRET_*`, `*_KEY_*`, `*_TOKEN_*`, `*_PASSWORD_*`. The skill confirms presence only.
- Execute `./gradlew bootRun` or any task that loads runtime credentials.
- Attempt to fetch a JWK Set from a remote URL — that's runtime behaviour, not static audit.

## Steps

- [ ] **Step 1: Detect applicability**

```bash
# Resource server starter on classpath (transitively or directly)
has_resource_server=$(grep -rlE 'spring-boot-starter-oauth2-resource-server|oauth2ResourceServer' \
  --include='*.gradle.kts' --include='*.kts' \
  --exclude-dir=build --exclude-dir='.gradle' . 2>/dev/null | head -1 || true)

# Or any direct nimbus-jose-jwt usage
has_nimbus=$(grep -rlE 'NimbusReactiveJwtDecoder|nimbus-jose-jwt' \
  --include='*.kt' --include='*.gradle.kts' \
  --exclude-dir=build --exclude-dir=test . 2>/dev/null | head -1 || true)
```

If both are empty: emit `{ "applicable": false, "reason": "no JWT decoder dependencies found" }` and stop. The audit returns INFO, not BLOCKER.

- [ ] **Step 2: Locate the decoder configuration**

```bash
decoder_files=$(grep -rlE 'ReactiveJwtDecoder\b|@EnableReactiveMethodSecurity\b|oauth2ResourceServer\s*\{' \
  --include='*.kt' \
  --exclude-dir=build --exclude-dir=test src/main 2>/dev/null || true)
```

For each file, read the relevant configuration block. Record what shape it takes:

- **JwkSetUri** — `NimbusReactiveJwtDecoder.withJwkSetUri("https://...")`. Most common.
- **PublicKey** — `NimbusReactiveJwtDecoder.withPublicKey(...)`. Static-key path.
- **SecretKey** — symmetric. Rare and notable.
- **Issuer-location** — `ReactiveJwtDecoders.fromIssuerLocation("https://...")`. Auto-discovers JWK Set URI.
- **Spring Boot autoconfig** — `spring.security.oauth2.resourceserver.jwt.issuer-uri=...` in `application.yaml`. The decoder is auto-built; settings come from the property file.

- [ ] **Step 3: Check the algorithm allowlist**

The default Nimbus decoder accepts whatever algorithm the JWT's `alg` header claims, validated against the JWK's stated algorithm. Custom configurations may opt into a restricted set:

```kotlin
NimbusReactiveJwtDecoder.withJwkSetUri(uri)
    .jwsAlgorithms { algs ->
        algs.add(SignatureAlgorithm.RS256)
        algs.add(SignatureAlgorithm.ES256)
        // explicit allowlist
    }
    .build()
```

For each decoder, record:
- The configured algorithm allowlist (if explicit)
- Or note "uses default Nimbus algorithm resolution" (which is normally safe but worth surfacing)

Findings:
- `none` (or `SignatureAlgorithm.none`) in any allowlist → **BLOCKER**.
- Both `RS*` (asymmetric) AND `HS*` (symmetric) in the same allowlist → **WARNING** (algorithm-confusion surface).
- Only `HS*` in a context that uses a JWK Set URI → **BLOCKER** (JWK Set is for asymmetric keys; symmetric expects a shared secret).

- [ ] **Step 4: Check JWK source refresh policy**

For JwkSetUri-based decoders, the default cache TTL is **5 minutes** for the keys but the decoder itself refreshes on key-not-found (unknown `kid`). For long-running services with quarterly key rotation, this is fine.

For PublicKey decoders (static keys), the project must have a documented rotation procedure — note WARNING if no `// ROTATION:` annotation or ADR reference accompanies the static key path.

- [ ] **Step 5: Check issuer + audience validators**

Spring's default `JwtValidators.createDefault()` validates `exp` and `nbf`. For multi-issuer or multi-audience setups, a custom validator is required:

```kotlin
val issuerValidator = JwtIssuerValidator("https://issuer.example.com")
val audienceValidator = JwtClaimValidator<List<String>>("aud") { it.contains("orders-service") }
val validator = DelegatingOAuth2TokenValidator(JwtValidators.createDefault(), issuerValidator, audienceValidator)
decoder.setJwtValidator(validator)
```

Findings:
- No issuer validation in a multi-issuer environment → **BLOCKER**.
- No audience validation in a service that expects audience-scoped tokens → **BLOCKER**.
- Custom validator that explicitly disables `JwtValidators.createDefault()` (= no `exp` check) → **BLOCKER**.

The skill detects these by reading the decoder configuration block. If only the default is in use AND the project has only one issuer (a heuristic: only one `issuer-uri` in the property files), no finding.

- [ ] **Step 6: Check test fixtures don't reuse production keys**

```bash
# Find any test that loads a production-shaped key (env var, public key file path matching prod patterns)
grep -rnE 'jwt\.secret|JWT_SECRET|signing-key|prod[_-]?(key|cert)' \
  --include='*.kt' --include='*.yaml' --include='*.properties' \
  src/test 2>/dev/null | head -10 || true
```

Findings:
- Any test configuration that references a prod-shaped key/secret env var → **WARNING**.
- A test that hard-codes a real-looking RSA public key (4096-bit, `BEGIN PUBLIC KEY` block) → **WARNING** (could be a leaked rotation candidate).

- [ ] **Step 7: Emit findings**

```json
{
  "applicable": true,
  "decoders": [
    {
      "file":         "boot/JwtConfig.kt:18",
      "shape":        "JwkSetUri",
      "issuer_uri":   "https://issuer.example.com/.well-known/jwks.json",
      "algorithms":   ["RS256"],
      "issuer_validator":   true,
      "audience_validator": true,
      "exp_enforced":       true,
      "findings":     []
    }
  ],
  "test_fixture_findings": [
    {
      "file":     "src/test/resources/application-test.yaml:12",
      "severity": "WARNING",
      "message":  "test config references JWT_SIGNING_KEY env var — confirm it differs from prod"
    }
  ]
}
```

## Output

The JSON above. Consumed by `security-auditor` for severity classification and report composition.

## Notes

- For projects using `spring-cloud-gateway` to validate tokens upstream and pass identity downstream as a header, the audit may classify "no JWT decoder needed" as INFO. The downstream services trust the gateway header — that's a different audit (gateway-level) and out of scope.
- The skill recognises both Java-style `@Bean fun jwtDecoder(...)` and Kotlin-DSL `oauth2ResourceServer { jwt { ... } }` configurations.
- If the decoder configuration uses `JwtAuthenticationConverter` to extract scopes/authorities, that's noted (INFO) but not part of this audit — scope handling is application-level.
