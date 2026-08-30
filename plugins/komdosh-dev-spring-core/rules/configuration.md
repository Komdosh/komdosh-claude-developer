# Spring Configuration

A configuration change is configuration-only; if logic must change too, that is a separate, stated step. Read `application.yaml`, its profile variants, and the existing `@ConfigurationProperties` classes first — the profile hierarchy in use is a fact to discover, not to assume.

- **Every value externalised with a default**: `${MAX_PENDING_ORDERS:100}`.
- **Feature switches default to `false`.** A flag shipped defaulting on never protected anything.
- **Typed `@ConfigurationProperties`, never `@Value`.** Typed binding fails at startup on a malformed value; `@Value` fails at first use, in production.
- `application-prod.yaml` holds environment-variable references only. **A secret literal in any committed YAML is a BLOCKER**, `application-local.yaml` included once it is tracked.

Verify with `./gradlew :boot:compileKotlin` — the properties class must bind.
