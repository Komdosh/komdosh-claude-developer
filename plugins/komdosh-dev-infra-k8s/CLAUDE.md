# CLAUDE.md — komdosh-dev-infra-k8s

Kubernetes manifest authoring, hardening, troubleshooting, and ArgoCD GitOps delivery on top of `komdosh-dev-infra-core`. One domain: run workloads on Kubernetes securely, sized correctly, delivered from git, and diagnosable when they fail — without ever mutating a cluster from here.

## What it adds

| Piece | Purpose |
|---|---|
| [`/k8s-manifest <workload>`](commands/k8s-manifest.md) | Author/refactor a hardened workload via `k8s-author`. |
| [`/k8s-audit`](commands/k8s-audit.md) | Audit manifests against restricted PSS + resources + reliability via `k8s-auditor`. |
| [`/k8s-debug <workload>`](commands/k8s-debug.md) | Root-cause diagnose a failing workload via `k8s-diagnostician`. |
| [`/argo-app <service>`](commands/argo-app.md) | Author an Application / ApplicationSet / AppProject via `k8s-author`. |
| [`/argo-audit`](commands/argo-audit.md) | GitOps hygiene audit — pinned prod revisions, scoped projects, prune/selfHeal, inline secrets. |
| [`/argo-diagnose <app>`](commands/argo-diagnose.md) | Diagnose OutOfSync / Degraded / sync-failure / drift via `k8s-diagnostician`. |
| [`k8s-author`](agents/k8s-author.md) | Writes secure-and-operable-by-default workloads *and* their ArgoCD delivery wrappers; never applies, never syncs. |
| [`k8s-auditor`](agents/k8s-auditor.md) | Read-only audit of the rendered manifests + GitOps hygiene, BLOCKER/WARNING/INFO. |
| [`k8s-diagnostician`](agents/k8s-diagnostician.md) | Read-only probe → root cause → minimal manifest-or-git fix, for workloads and apps alike. |
| [`discover-k8s-workloads`](skills/discover-k8s-workloads/SKILL.md) | Inventory packaging, workloads, networking, config → descriptor. |
| [`probe-cluster-state`](skills/probe-cluster-state/SKILL.md) | Read-only live evidence (describe/logs/events/top) for diagnosis. |
| [`discover-argocd-apps`](skills/discover-argocd-apps/SKILL.md) | Inventory Applications/ApplicationSets/AppProjects, sources, sync policy, waves. |
| [`probe-app-health`](skills/probe-app-health/SKILL.md) | Read-only live sync/health status, out-of-sync resources, diff, conditions. |
| `rules/*.md` | Five convention documents, imported via `@rules/...` below. |

## Big picture

Three agents, three disjoint verbs: **author** writes, **auditor** critiques, **diagnostician** diagnoses. The split is by *what you're doing*, not by *which tool you're doing it with* — a Deployment and the ArgoCD Application that ships it are two halves of one change, so one author owns both, and an app that is Degraded because its pod is crashing is one diagnosis, not a hand-off between two agents.

None of them mutates anything. This plugin owns the git side of GitOps (manifests and delivery wrappers) and read-only cluster/ArgoCD inspection — never `apply`/`edit`/`delete`, never `argocd app sync/set/rollback`. Rollback is `git revert` to the last pinned revision. Provisioning the cluster itself (node groups, load balancers, storage classes, managed control planes) belongs to `komdosh-dev-infra-iac`; this plugin deploys *into* a cluster.

The author and auditor both work on the **rendered** manifest (`kustomize build`, `helm template`) — an overlay can silently fail to apply a hardening patch that's present in the base, so source-only review misses real regressions. The diagnostician is evidence-first: it probes read-only, separates *sync* status (does the cluster match git?) from *health* status (do the resources work?), and states the evidence chain before proposing a fix — never a workaround that hides the symptom, and never a manual `kubectl edit`, which is exactly the drift GitOps exists to prevent.

## Defaults the author never skips (unless justified)

**Workloads**: restricted Pod Security Standards (`runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL caps, `seccompProfile: RuntimeDefault`, no host namespaces, `automountServiceAccountToken: false`), requests+limits on every container with memory limit == request, all three probe types with readiness ≠ liveness, graceful shutdown (SIGTERM + preStop), a PDB, topology spread, immutable images, and secrets from a store.

**Delivery**: a pinned prod `targetRevision`, a scoped AppProject (never `default`), `automated` sync with `prune` + `selfHeal`, a `resources-finalizer`, sync waves where ordering matters, and narrowly-scoped `ignoreDifferences`.

Every opt-out carries a one-line justification comment.

## Conventions imported as rules

- **`k8s-manifests.md`** — workload type choice, the standard `app.kubernetes.io/*` labels, immutable images, the three probes and their distinct jobs (readiness=traffic, liveness=restart, startup=slow boot), graceful shutdown, RollingUpdate + PDB + topology spread + HPA, config in ConfigMaps.
- **`k8s-security.md`** — restricted PSS securityContext, host-isolation forbidden by default, dedicated ServiceAccount + `automountServiceAccountToken: false`, RBAC least privilege (no wildcards/cluster-admin), default-deny NetworkPolicy, secrets from a store mounted as files, minimal/distroless images.
- **`k8s-resources.md`** — always set requests+limits, memory limit == request (incompressible resource), CPU request always + limit deliberately, the three QoS classes (target Guaranteed for critical, never BestEffort in prod), LimitRange/ResourceQuota guardrails, right-size from observed usage.
- **`argocd-applications.md`** — Application/ApplicationSet/AppProject shape, revision pinning, sync policy and options, sync waves and hooks, `ignoreDifferences` scoping, app-of-apps structure.
- **`gitops-delivery.md`** — git as the single source of truth, promotion by advancing a pinned revision, drift correction via selfHeal, rollback as git revert, and why an out-of-band cluster edit is never the fix.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + `allowed-tools` for internal read-only skills — `probe-cluster-state` allows only read-only `kubectl`, `probe-app-health` only read-only `argocd`).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/k8s-manifests.md
@rules/k8s-security.md
@rules/k8s-resources.md
@rules/argocd-applications.md
@rules/gitops-delivery.md
