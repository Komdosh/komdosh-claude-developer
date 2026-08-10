# Kubernetes Resource Management

Requests and limits are not optional. Without them the scheduler can't place pods correctly and one workload's leak evicts its neighbors. Getting them right is the difference between a stable cluster and 3am OOMKills.

## Always set requests and limits

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "1000m"
    memory: "256Mi"
```

- **requests** — what the scheduler reserves; the guaranteed floor. Set to the workload's steady-state need. Too low → the node oversubscribes and pods get starved/evicted; too high → wasted capacity.
- **limits** — the hard ceiling. Exceeding the memory limit → **OOMKilled**; exceeding the CPU limit → **throttled** (not killed).

## Memory: limit == request

Set **memory limit equal to memory request**. Memory is incompressible — a pod using between request and limit is a time bomb: it schedules fine, then gets OOMKilled under load with no warning. Equal request/limit makes the pod's memory footprint explicit and predictable, and gives it **Guaranteed** QoS.

## CPU: request always, limit with care

- Always set a CPU **request** (for scheduling and fair sharing).
- A CPU **limit** caps burst and causes throttling that can spike latency. For latency-sensitive services, consider a generous limit or none (relying on requests for fairness); for batch/untrusted workloads, a limit contains noisy neighbors. Decide deliberately — don't copy a limit blindly.

## Quality of Service

| QoS class | Condition | Eviction order |
|---|---|---|
| **Guaranteed** | every container has requests == limits (cpu + memory) | evicted last |
| **Burstable** | requests set, limits higher or absent | evicted after BestEffort |
| **BestEffort** | no requests or limits | **evicted first** |

Critical workloads target **Guaranteed**. **Never ship a BestEffort production workload** — it's first to die under node pressure and can't be scheduled predictably.

## Namespace guardrails

- **LimitRange** — per-namespace default requests/limits and min/max, so a manifest that forgets resources still gets sane defaults instead of BestEffort.
- **ResourceQuota** — caps total requests/limits per namespace, so one team can't consume the whole cluster.

## Right-sizing

- Base requests on **observed** usage (metrics-server / VPA recommendations / historical p95), not a guess. Over-requesting wastes money; under-requesting causes evictions.
- Revisit after load changes. A request set at launch is rarely right a quarter later.
- Autoscale horizontally (HPA) on a real signal before scaling pods vertically; vertical changes (VPA) restart the pod.
