---
description: Author or refactor a hardened Kubernetes workload — restricted Pod Security Standards, resource requests/limits, all three probes, graceful shutdown, PDB, topology spread, immutable images. Never applies.
argument-hint: <workload-name> [--kind=Deployment|StatefulSet|Job] [--env=<overlay>]
---

Invoke the `k8s-author` agent to write or refactor Kubernetes manifests for `$ARGUMENTS`.

- **workload** — the first positional argument (service/workload name).
- **kind** — `--kind=` if the default (Deployment) isn't right.
- **env** — target overlay/values env if the change is env-specific (kept as a delta, not a full restatement).

The agent runs `discover-k8s-workloads` to match the repo's packaging (plain/Kustomize/Helm), then writes manifests that are secure and operable by default — restricted securityContext, requests+limits (memory limit == request), readiness+liveness+startup probes, graceful shutdown, a PDB, topology spread, and immutable image references, with secrets pulled from a store. It renders read-only to verify overlays actually override, and never applies to a cluster (GitOps or a human does). Follow with `/k8s-audit`.
