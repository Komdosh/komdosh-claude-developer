# Spring Configuration Rules

Configuration changes are configuration-only. If business logic must change too, that is a separate, explicitly-stated step.

Read `src/main/resources/application.yaml`, its profile variants, and the existing `@ConfigurationProperties` classes before adding anything — the profile hierarchy in use is a fact to discover, not to assume.

## Every value is externalised with a default

```yaml
spring:
  application:
    name: ${SERVICE_NAME:order-service}

# Feature switches — all default to OFF
features:
  new-checkout-flow:
    enabled: ${FEATURE_NEW_CHECKOUT:false}

order-service:
  max-pending-orders: ${MAX_PENDING_ORDERS:100}
  processing-timeout-seconds: ${PROCESSING_TIMEOUT_SECONDS:30}
```

A feature switch defaults to `false`. Shipping a flag that defaults on means the flag never protected anything.

## Bind to typed classes, never `@Value`

```kotlin
@ConfigurationProperties(prefix = "order-service")
data class OrderServiceProperties(
    val maxPendingOrders: Int = 100,
    val processingTimeoutSeconds: Long = 30
)

@Configuration
@EnableConfigurationProperties(OrderServiceProperties::class)
class ServiceConfiguration
```

Typed binding fails at startup on a malformed value; `@Value` fails at first use, in production, at 3am.

## Profiles

| File | Purpose |
|---|---|
| `application.yaml` | Defaults that work in every environment |
| `application-local.yaml` | Local dev overrides (gitignored) |
| `application-test.yaml` | Test-context overrides |
| `application-prod.yaml` | Production — **environment variables only, never a literal secret** |

A secret literal in any committed YAML is a BLOCKER, including in `application-local.yaml` if it is ever tracked. Secrets come from the environment or a secret store.

## Verify

```bash
./gradlew :boot:compileKotlin 2>&1 | tail -10
```

Expected: `BUILD SUCCESSFUL` — the config class binds without errors.
