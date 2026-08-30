---
description: Audit JWT/JWK plumbing — decoder presence, algorithm allowlist, JWK refresh, issuer and audience validation, expiry enforcement, and test-fixture keys.
---

# /jwt-rotation

`security-auditor --scope=jwt`. Narrow slice of `/security-audit`.

`read-service-context` first; refuse on the library track. **No OAuth2 resource server → return INFO "not applicable" and stop** — that is not a gap.

Checks and severities are in `rules/security-audit.md`. The two that matter most and are most often missing: `none` in the algorithm allowlist, and **issuer/audience validation** — a token signed with the right key but issued for another audience must be rejected, and signature-only verification accepts it.

**Never read or print key material.** Report configuration shape only.

Write `docs/security/jwt-rotation-YYYY-MM-DD.md`.
