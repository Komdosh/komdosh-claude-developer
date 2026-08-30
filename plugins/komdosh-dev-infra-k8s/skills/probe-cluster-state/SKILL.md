---
name: probe-cluster-state
user-invocable: false
allowed-tools: Read, Bash(kubectl get:*), Bash(kubectl describe:*), Bash(kubectl logs:*), Bash(kubectl top:*), Bash(kubectl events:*), Bash(kubectl config current-context:*)
description: Read-only live probe of a running Kubernetes workload when a kubeconfig/context is reachable — pod phase and readiness, restart counts, recent events, container waiting/terminated reasons (CrashLoopBackOff/ImagePullBackOff/OOMKilled), resource pressure, and recent logs. Gathers the evidence a diagnosis needs without mutating anything (get/describe/logs/top/events only). Degrades to "no cluster reachable — reason from manifests" when there is no context. Used by k8s-diagnostician.
---

# Probe Cluster State

Collect the read-only evidence needed to diagnose a failing workload. **Never** mutates the cluster — only `get`, `describe`, `logs`, `top`, `events`. If no cluster is reachable, say so and fall back to manifest-only reasoning.

## 0. Confirm a cluster is reachable

- `kubectl config current-context` — record which context/cluster is targeted. **Confirm it is the intended one** before probing (never probe prod by accident).
- If no context or the API is unreachable → set `reachable: false`, stop probing, and tell the caller to reason from manifests + provided symptoms instead.

## 1. Workload and pod status

- `kubectl get deploy,sts,pods -n <ns> -l <selector> -o wide` — desired vs ready vs available replicas; pod phase; node placement.
- Note pods `Pending` (unschedulable), `CrashLoopBackOff`, `ImagePullBackOff`/`ErrImagePull`, `OOMKilled` (in last-terminated state), or high restart counts.

## 2. The failing pod, in detail

- `kubectl describe pod <pod> -n <ns>` — the `Events` section is the primary signal: FailedScheduling, Failed pull, Liveness/Readiness probe failed, OOMKilled, FailedMount.
- Container statuses: `state.waiting.reason` / `lastState.terminated.reason` + `exitCode` (137 = OOM/SIGKILL, 143 = SIGTERM, 1/2 = app error).

## 3. Logs

- `kubectl logs <pod> -n <ns> --previous` — the **previous** container's logs are where a crash's cause lives; the current container may be too young to have logged it.
- `kubectl logs <pod> -n <ns> -c <container>` for the current attempt and for sidecars/init containers.

## 4. Pressure and scheduling

- `kubectl get events -n <ns> --sort-by=.lastTimestamp` — cluster-level signals (evictions, node pressure, quota rejections).
- `kubectl top pod <pod> -n <ns>` / `kubectl top node` (if metrics-server present) — is the pod near its memory limit? Is the node out of allocatable CPU/memory?
- For `Pending`: `describe` shows the scheduler reason (insufficient cpu/memory, taints, unsatisfiable affinity, unbound PVC).

## 5. Return the evidence bundle

```json
{
  "reachable": true,
  "context": "<cluster/context>",
  "workload": { "name": "…", "desired": 3, "ready": 1 },
  "symptom": "CrashLoopBackOff|ImagePullBackOff|OOMKilled|Pending|ProbeFailure|NotReady|Unknown",
  "key_events": ["<verbatim describe/event lines>"],
  "container_state": { "waiting_reason": "…", "last_terminated_reason": "…", "exit_code": 137, "restarts": 12 },
  "logs_excerpt": "<the decisive lines from --previous>",
  "pressure": { "near_mem_limit": true, "node_allocatable_exhausted": false },
  "notes": "…"
}
```

This is evidence, not a diagnosis — `k8s-diagnostician` maps it to a root cause and a fix. If `reachable: false`, return that plainly so the caller reasons from manifests instead of inventing cluster state.
