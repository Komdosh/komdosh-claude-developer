# Kubernetes Manifest Conventions

Shape and reliability rules for workload manifests. Security is in `rules/k8s-security.md`; sizing is in `rules/k8s-resources.md`; this file is about correct, operable workloads.

## Workload type

- **Deployment** — stateless, interchangeable replicas (APIs, workers). The default.
- **StatefulSet** — stable identity + per-replica storage (databases, brokers). Use only when a pod needs a stable name/PVC/ordinal; otherwise Deployment.
- **DaemonSet** — one per node (log/metric agents, CNI).
- **Job/CronJob** — run-to-completion / scheduled. Set `backoffLimit`, `activeDeadlineSeconds`, and (CronJob) `concurrencyPolicy` + `startingDeadlineSeconds`.

## Labels — the recommended set

Every object carries the standard labels so selectors, dashboards, and cost tooling work:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: order-service
    app.kubernetes.io/instance: order-service-prod
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: commerce
    app.kubernetes.io/managed-by: argocd
```

A Deployment's `spec.selector.matchLabels` must be a **stable subset** of the pod labels — selectors are immutable after creation, so a wrong selector forces a delete+recreate.

## Images

- **Immutable references only** — a digest (`@sha256:…`) or a unique semver/commit tag. Never `:latest`, `:main`, or untagged (see infra-core `rules/iac-safety.md`).
- `imagePullPolicy: IfNotPresent` with an immutable tag; `Always` only if you (wrongly) use mutable tags.
- Private registries reference an `imagePullSecrets` that comes from a secret store, never a committed plaintext secret.

## Probes — all three have distinct jobs

```yaml
startupProbe:      # slow starters: gates liveness until the app is up; prevents early kills
  httpGet: { path: /healthz, port: 8080 }
  failureThreshold: 30
  periodSeconds: 5
readinessProbe:    # gates traffic: fail → removed from Service endpoints, not killed
  httpGet: { path: /readyz, port: 8080 }
  periodSeconds: 5
livenessProbe:     # gates restart: fail → kubelet kills the container
  httpGet: { path: /healthz, port: 8080 }
  periodSeconds: 10
```

- **Readiness ≠ liveness.** Readiness controls traffic; liveness controls restarts. Pointing liveness at a dependency check causes restart storms when a downstream is slow — liveness should test only "is this process wedged."
- Use `startupProbe` for slow boots instead of a large `livenessProbe.initialDelaySeconds`.

## Graceful shutdown

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
    - name: app
      lifecycle:
        preStop:
          exec: { command: ["sh", "-c", "sleep 5"] }   # let the LB deregister before SIGTERM handling ends
```

The app must handle `SIGTERM`: stop accepting new work, drain in-flight requests, exit before the grace period. A pod that ignores SIGTERM is SIGKILLed and drops requests on every rollout.

## Rollout, disruption, and spread

- **Deployment strategy** — `RollingUpdate` with explicit `maxUnavailable`/`maxSurge`; never leave a critical service able to drop to zero ready pods mid-rollout.
- **PodDisruptionBudget** — every multi-replica workload has a PDB (`minAvailable`/`maxUnavailable`) so node drains and cluster upgrades can't evict all replicas at once.
- **Topology spread / anti-affinity** — spread replicas across nodes/zones so one node or zone loss doesn't take the whole service down.
- **HorizontalPodAutoscaler** — for elastic workloads, scale on a real signal (CPU/memory/custom); set sane `minReplicas`/`maxReplicas`.

## Configuration

- Non-secret config in `ConfigMap`; secrets never in a ConfigMap and never plaintext (see `rules/secrets-hygiene.md`).
- Prefer projecting config as files or explicit env; changing a ConfigMap does not restart pods by itself — use a checksum annotation or a controller that rolls on change.
