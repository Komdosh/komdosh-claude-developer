---
description: Audit Kubernetes manifests against Pod Security Standards restricted, resource discipline, and reliability conventions — classified BLOCKER/WARNING/INFO. Renders overlays read-only. Never applies.
argument-hint: [--env=<overlay>] [--path=<dir>]
---

Run a hardening audit with the `k8s-auditor` agent.

- `--env=` audits a specific overlay/values environment; otherwise it audits what it finds.
- `--path=` scopes to a subtree.

The agent runs `discover-k8s-workloads`, renders the **effective** manifests (`kustomize build` / `helm template`) read-only so overlay regressions are caught, and reports every gap against restricted PSS (root, writable root FS, missing capability drops, host namespaces, mounted API tokens, wildcard RBAC, missing default-deny NetworkPolicy), resource discipline (missing requests/limits, BestEffort prod, memory limit ≠ request), and reliability (missing probes/PDB/topology spread, liveness on a dependency, mutable images).

Output is a BLOCKER/WARNING/INFO report with file:line and concrete impact. Plaintext Secrets route to `secrets-sentinel`; fixes route to `k8s-author`. Read-only — never applies or edits.
