# /jwt-rotation

Audit JWT/JWK plumbing: `ReactiveJwtDecoder` presence, algorithm allowlist, JWK source refresh, issuer + audience validators, expiration enforcement, no production keys in test fixtures.

Narrow scope of `/security-audit`. Returns INFO ("not applicable") if the project doesn't use Spring Security OAuth2 resource server.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if not already run. Refuse on library track.

- [ ] **Step 2: Invoke `security-auditor` with `--scope=jwt`**

The agent runs `audit-jwt-rotation`. The skill emits `applicable: false` if no JWT decoder dependency is detected — surface that as INFO and stop.

- [ ] **Step 3: Print findings**

```
== JWT/JWK Audit ==

Decoder:        boot/JwtConfig.kt:18 (NimbusReactiveJwtDecoder.withJwkSetUri)
Issuer:         https://issuer.example.com/.well-known/jwks.json
Algorithms:     [RS256]                                                  ✓
Issuer check:   YES                                                      ✓
Audience check: YES                                                      ✓
exp enforced:   YES (default)                                            ✓
JWK refresh:    default Nimbus cache (5 min) + on-unknown-kid refresh    ✓

Findings: 1

  WARNING — src/test/resources/application-test.yaml:12 references JWT_SIGNING_KEY env var.
  Confirm test fixtures do NOT reuse the production key. Recommended: use a
  fresh RSA key pair per test class via JWKSource fixtures from nimbus-jose-jwt.
```

- [ ] **Step 4: Suggest fixes**

| Finding | Recommended remediation |
|---|---|
| `none` algorithm allowed | Edit the decoder config to explicitly set `jwsAlgorithms { it.add(SignatureAlgorithm.RS256) }` (or your asymmetric set). Re-run audit. |
| Symmetric + asymmetric in the same allowlist | Pick one. Asymmetric (`RS*` / `ES*`) is the default for OAuth2 resource servers. |
| Missing issuer validator (multi-issuer service) | Add `JwtIssuerValidator(...)` to a `DelegatingOAuth2TokenValidator`. |
| Missing audience validator (audience-scoped tokens) | Add `JwtClaimValidator<List<String>>("aud") { it.contains("<service-name>") }`. |
| Test fixtures using prod-shaped keys | Refactor to generate per-test RSA pairs (`JWKSet.generate()` from nimbus-jose-jwt). |

These are configuration changes — apply directly in `boot/JwtConfig.kt` (or wherever the decoder is wired). After the fix, re-run `/jwt-rotation` to confirm.

- [ ] **Step 5: Write the report**

Output: `docs/security/jwt-rotation-YYYY-MM-DD.md`.
