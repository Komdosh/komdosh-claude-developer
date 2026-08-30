# Kubernetes Manifest Conventions

Correct, operable workloads. Security is `rules/k8s-security.md`; sizing is `rules/k8s-resources.md`.

## Workload type

**Deployment** is the default — stateless, interchangeable replicas. **StatefulSet** only when a pod genuinely needs a stable name, PVC, or ordinal. **DaemonSet** for node agents. **Job/CronJob** with `backoffLimit`, `activeDeadlineSeconds`, and — for CronJob — `concurrencyPolicy` and `startingDeadlineSeconds`.

## Labels

The standard `app.kubernetes.io/*` set — `name`, `instance`, `component`, `part-of`, `managed-by` — on every object, so selectors, dashboards, and cost tooling work.

**A Deployment's `spec.selector.matchLabels` must be a stable subset of the pod labels.** Selectors are immutable after creation, so getting one wrong forces a delete-and-recreate.

## Images

**Immutable references only** — a digest or a unique tag; never `:latest`, `:main`, or untagged. `imagePullPolicy: IfNotPresent` follows from that. Pull secrets come from a secret store.

## The three probes do different jobs

- **`startupProbe`** gates liveness while a slow app boots — use it instead of a large `livenessProbe.initialDelaySeconds`.
- **`readinessProbe`** gates *traffic*: failing removes the pod from Service endpoints.
- **`livenessProbe`** gates *restarts*: failing kills the container.

**Readiness ≠ liveness, and liveness must not check a dependency.** A liveness probe that tests a downstream causes restart storms whenever that downstream is slow — it should only answer "is this process wedged".

## Graceful shutdown

`terminationGracePeriodSeconds` plus a `preStop` sleep long enough for the load balancer to deregister, and an app that handles `SIGTERM`: stop accepting work, drain, exit. **A pod that ignores SIGTERM is SIGKILLed and drops requests on every rollout.**

## Rollout and disruption

`RollingUpdate` with explicit `maxUnavailable`/`maxSurge` — **never let a critical service reach zero ready pods mid-rollout** · a **PodDisruptionBudget** on every multi-replica workload, so a node drain or cluster upgrade can't evict every replica at once · topology spread or anti-affinity across nodes and zones · an HPA on a real signal with sane bounds for elastic workloads.

## Configuration

Non-secret config in a ConfigMap; secrets never there and never plaintext. **Changing a ConfigMap does not restart pods** — use a checksum annotation or a controller that rolls on change, or the new config silently never takes effect.
