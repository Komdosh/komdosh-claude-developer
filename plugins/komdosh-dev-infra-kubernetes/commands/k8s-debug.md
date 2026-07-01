---
description: Diagnose a failing Kubernetes workload by root cause (CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending, probe failures) and propose the minimal manifest fix. Read-only on the cluster.
argument-hint: <workload> [--namespace=<ns>] [--context=<ctx>]
---

Invoke the `k8s-troubleshooter` agent to diagnose `$ARGUMENTS`.

- **workload** — the failing Deployment/StatefulSet/pod name.
- **namespace** — `--namespace=` if not default.
- **context** — `--context=` to be explicit about which cluster (the agent confirms the target context before probing — it never probes the wrong cluster).

The agent gathers read-only evidence via `probe-cluster-state` (describe, previous-container logs, events, top), maps the symptom to its **actual** root cause with an explicit evidence chain, and proposes the smallest manifest change that fixes the cause — routed to `k8s-manifest-author` / GitOps to apply.

It never mutates the cluster and never chains a workaround to hide the symptom. If no cluster is reachable, it reasons from the manifests plus the symptoms you provide, and says so.
