# komdosh-dev-infra-k8s

Kubernetes manifests, hardening, troubleshooting, and ArgoCD delivery on top of `komdosh-dev-infra-core`. One domain: **run workloads securely, sized correctly, delivered from git, and diagnosable when they fail — without ever mutating a cluster from here.**

## Three agents, three disjoint verbs

**author** writes · **auditor** critiques · **diagnostician** diagnoses.

The split is by *what you're doing*, not *which tool you're doing it with*. A Deployment and the ArgoCD Application that ships it are two halves of one change, so one author owns both — and an app that is Degraded because its pod is crashing is one diagnosis, not a hand-off between two agents.

## Nothing here mutates

This plugin owns the **git side** of GitOps plus read-only cluster and ArgoCD inspection. Never `apply`/`edit`/`delete`, never `argocd app sync/set/rollback`. **Rollback is `git revert` to the last pinned revision.**

Provisioning the cluster itself — node groups, load balancers, storage classes, managed control planes — belongs to `komdosh-dev-infra-iac`. This plugin deploys *into* a cluster.

## Two habits that catch what source review misses

**Author and auditor work on the rendered manifest** (`kustomize build`, `helm template`). An overlay can silently fail to apply a hardening patch that is present in the base, so source-only review passes a real regression.

**The diagnostician is evidence-first**: probe read-only, **separate sync status from health status**, state the evidence chain, then propose a fix. Never a workaround that hides the symptom, and never a `kubectl edit` — that is exactly the drift GitOps exists to prevent.

## Defaults the author never silently skips

**Workloads**: restricted Pod Security Standards · requests and limits with memory limit == request · all three probe types with readiness ≠ liveness · graceful shutdown · a PDB · topology spread · immutable images · secrets from a store.

**Delivery**: a pinned prod `targetRevision` · a scoped AppProject · `automated` sync with `prune` and `selfHeal` · a resources-finalizer · sync waves where ordering matters · narrowly-scoped `ignoreDifferences`.

**Every opt-out carries a one-line justification comment.** An undocumented one is indistinguishable from an oversight.

@rules/k8s-manifests.md
@rules/k8s-security.md
@rules/k8s-resources.md
@rules/argocd-applications.md
@rules/gitops-delivery.md
