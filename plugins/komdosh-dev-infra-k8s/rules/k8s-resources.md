# Kubernetes Resource Management

Without requests and limits the scheduler cannot place pods correctly and one workload's leak evicts its neighbours.

**Requests** are what the scheduler reserves — the guaranteed floor, set to steady-state need. **Limits** are the hard ceiling: exceeding memory means **OOMKilled**, exceeding CPU means **throttled**.

## Memory limit == memory request

Memory is incompressible. A pod allowed to use between its request and its limit **schedules fine and then gets OOMKilled under load with no warning**. Equal request and limit makes the footprint explicit and earns the pod **Guaranteed** QoS.

## CPU: always request, limit deliberately

Always set a CPU request, for scheduling and fair sharing. A CPU limit caps burst and **causes throttling that shows up as latency spikes** — for latency-sensitive services consider a generous limit or none, relying on requests for fairness; for batch or untrusted workloads a limit contains noisy neighbours. **Decide; don't copy a limit blindly.**

## QoS decides who dies first

**Guaranteed** (requests == limits on every container) is evicted last · **Burstable** next · **BestEffort** (nothing set) **first**.

Critical workloads target Guaranteed. **Never ship a BestEffort production workload** — it is first to die under node pressure and cannot be scheduled predictably.

## Namespace guardrails

A **LimitRange** gives defaults and bounds, so a manifest that forgets resources still gets something sane instead of BestEffort. A **ResourceQuota** stops one team consuming the cluster.

## Right-sizing

Base requests on **observed** usage — metrics, VPA recommendations, historical p95 — not a guess. Revisit after load changes; a request set at launch is rarely right a quarter later. **Scale horizontally on a real signal before scaling vertically**, since a vertical change restarts the pod.
