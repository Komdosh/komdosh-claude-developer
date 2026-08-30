# Local Development and Packaging

Docker Compose for dependencies, and the service's own Dockerfile.

**Kubernetes manifests, Helm charts, ArgoCD Applications, and CI pipelines are out of scope here** — they belong to `komdosh-dev-infra-k8s` / `komdosh-dev-infra-core`, which own the hardening rules. A deployment manifest written from this plugin is one those plugins correctly reject.

## Compose — dependencies only

Compose runs the service's dependencies (database, broker, registry); the service itself runs from the IDE or `bootRun` so a debugger stays attached. Omit the deprecated top-level `version:` key.

- **Every dependency declares a `healthcheck`**, so `depends_on: condition: service_healthy` waits instead of racing.
- **Pin image tags** (`postgres:16-alpine`) — a silent major bump breaks everyone at once.
- Default credentials here are local-only; a real credential never appears in a committed compose file.
- Integration tests use Testcontainers (`rules/testing.md`), never this stack — a test must not depend on a manually-started environment.

## Dockerfile — multi-stage, non-root

- **A non-root `USER` with an explicit non-zero UID** (create the user in the final stage). The runtime enforces `runAsNonRoot`, and an image whose only user is root **cannot start there** — getting this right in the image is what makes the deployment rule satisfiable.
- JRE (not JDK) in the final stage; the build toolchain never ships.
- **Never `COPY` a secret, `.env`, or keystore into a layer.** Layers are extractable forever, even if a later layer deletes the file.
- The build produces an immutable unique tag (commit SHA or version), never `:latest`.
