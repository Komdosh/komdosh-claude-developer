# Local Development Environment Rules

Covers what a service needs to run on a developer's machine and to be packaged: Docker Compose for dependencies, and the service's own Dockerfile.

**Kubernetes manifests, Helm charts, ArgoCD Applications, and CI pipeline definitions are out of scope here** — they belong to `komdosh-dev-infra-k8s` and `komdosh-dev-infra-core`, which own the hardening rules (restricted Pod Security Standards, resource requests/limits, immutable image references). Writing a deployment manifest from this plugin would produce something those plugins correctly reject.

## Docker Compose — dependencies only

Compose runs the service's *dependencies* (database, broker, registry), not the service itself; the service runs from the IDE or `bootRun` so you keep a debugger. The top-level `version:` key is deprecated in Compose v2 — omit it.

```yaml
# docker-compose.yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${DB_NAME:-servicedb}
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app} -d ${DB_NAME:-servicedb}"]
      interval: 5s
      timeout: 3s
      retries: 5
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

- Every dependency has a **healthcheck**, so `depends_on: condition: service_healthy` actually waits instead of racing.
- Pin image tags (`postgres:16-alpine`, never `postgres:latest`) — a silent major bump breaks everyone at once.
- The default credentials above are local-only. A real credential never appears in a committed compose file.
- Integration tests use Testcontainers (`rules/testing.md`), not this compose stack — tests must not depend on a manually-started environment.

## Dockerfile — multi-stage, non-root

```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN ./gradlew :boot:bootJar -x test --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S -G app -u 10001 app
WORKDIR /app
COPY --from=build --chown=app:app /app/boot/build/libs/*.jar app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- **Non-root `USER` with an explicit non-zero UID.** The runtime enforces `runAsNonRoot`, and an image whose only user is root cannot start there. Getting this right in the image is what makes the deployment rule satisfiable.
- **JRE, not JDK, in the final stage** — smaller image, smaller attack surface.
- **Build stage is separate** so the toolchain never ships to production.
- Never `COPY` a secret, a `.env`, or a keystore into an image layer; layers are extractable forever, even if a later layer deletes the file.

## Image tags

The build produces an immutable, unique tag (commit SHA or version), never `:latest`. Deployment references that exact tag or its digest — see `komdosh-dev-infra-k8s`'s `rules/k8s-manifests.md`.

## Do not

- Change `build.gradle.kts` or the version catalog from here — that's `rules/gradle-build.md`.
- Write Kubernetes/Helm/ArgoCD manifests or CI pipelines — that's the infra plugins.
- Put a plaintext secret in any committed file.
