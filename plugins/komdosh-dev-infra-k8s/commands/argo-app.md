---
description: Author an ArgoCD Application / ApplicationSet / AppProject — pinned prod revision, scoped project, automated sync with prune+selfHeal, sync waves, finalizers. Produces reviewable git manifests; never syncs.
argument-hint: <app-name> [--kind=Application|ApplicationSet|AppProject] [--env=<env>]
---

Invoke the `k8s-author` agent to write ArgoCD delivery manifests for `$ARGUMENTS`.

- **app-name** — the first positional argument (service/app to onboard).
- **kind** — `--kind=` to author an ApplicationSet (fan-out across envs/clusters) or an AppProject (guardrail) instead of a single Application.
- **env** — target environment; prod gets a pinned `targetRevision`, lower envs may track a branch.

The agent runs `discover-argocd-apps` to match existing conventions, then writes GitOps-correct manifests: pinned prod revision, a scoped AppProject (never `default`), `automated` sync with `prune`+`selfHeal`, sensible `syncOptions`, the resources-finalizer, sync waves where ordering matters, and secrets referenced from a store (never inline).

The change lands as a git PR; ArgoCD syncs it — the agent never runs `argocd app sync` or mutates a cluster. Follow with `/argo-audit` before prod.
