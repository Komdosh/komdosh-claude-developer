# CLAUDE.md — komdosh-dev-infra-kubernetes

Kubernetes manifest authoring, hardening, and troubleshooting on top of `komdosh-dev-infra-core`. One domain: run workloads on Kubernetes securely, sized correctly, and diagnosable when they fail — without ever mutating a cluster from here.

## What it adds

| Piece | Purpose |
|---|---|
| [`/k8s-manifest <workload>`](commands/k8s-manifest.md) | Author/refactor a hardened workload via `k8s-manifest-author`. |
| [`/k8s-audit`](commands/k8s-audit.md) | Audit manifests against restricted PSS + resources + reliability via `k8s-hardening-auditor`. |
| [`/k8s-debug <workload>`](commands/k8s-debug.md) | Root-cause diagnose a failing workload via `k8s-troubleshooter`. |
| [`k8s-manifest-author`](agents/k8s-manifest-author.md) | Writes secure-and-operable-by-default manifests; never applies. |
| [`k8s-hardening-auditor`](agents/k8s-hardening-auditor.md) | Read-only audit of the rendered manifests, BLOCKER/WARNING/INFO. |
| [`k8s-troubleshooter`](agents/k8s-troubleshooter.md) | Read-only cluster probe → root cause → minimal manifest fix. |
| [`discover-k8s-workloads`](skills/discover-k8s-workloads/SKILL.md) | Inventory packaging, workloads, networking, config → descriptor. |
| [`probe-cluster-state`](skills/probe-cluster-state/SKILL.md) | Read-only live evidence (describe/logs/events/top) for diagnosis. |
| `rules/*.md` | Three convention documents, imported via `@rules/...` below. |

## Big picture

Three agents, three disjoint jobs: **author** writes, **auditor** critiques, **troubleshooter** diagnoses. None of them mutates a cluster — this plugin owns the git side of GitOps (manifests) and read-only cluster inspection, never `apply`/`edit`/`delete`. Provisioning the cluster itself (node groups, load balancers, storage classes, managed control plane) belongs to `terraform-author`/`yc-provisioner`; this plugin deploys *into* a cluster.

The author and auditor both work on the **rendered** manifest (`kustomize build`, `helm template`) — an overlay can silently fail to apply a hardening patch that's present in the base, so source-only review misses real regressions. The troubleshooter is evidence-first: `probe-cluster-state` gathers `describe`/previous-logs/events/`top` read-only, and the diagnosis states the evidence chain before proposing a fix — never a workaround that hides the symptom.

## Defaults the author never skips (unless justified)

Restricted Pod Security Standards (`runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL caps, `seccompProfile: RuntimeDefault`, no host namespaces, `automountServiceAccountToken: false`), requests+limits on every container with memory limit == request, all three probe types with readiness ≠ liveness, graceful shutdown (SIGTERM + preStop), a PDB, topology spread, immutable images, and secrets from a store. Every opt-out carries a one-line justification comment.

## Conventions imported as rules

- **`k8s-manifests.md`** — workload type choice, the standard `app.kubernetes.io/*` labels, immutable images, the three probes and their distinct jobs (readiness=traffic, liveness=restart, startup=slow boot), graceful shutdown, RollingUpdate + PDB + topology spread + HPA, config in ConfigMaps.
- **`k8s-security.md`** — restricted PSS securityContext, host-isolation forbidden by default, dedicated ServiceAccount + `automountServiceAccountToken: false`, RBAC least privilege (no wildcards/cluster-admin), default-deny NetworkPolicy, secrets from a store mounted as files, minimal/distroless images.
- **`k8s-resources.md`** — always set requests+limits, memory limit == request (incompressible resource), CPU request always + limit deliberately, the three QoS classes (target Guaranteed for critical, never BestEffort in prod), LimitRange/ResourceQuota guardrails, right-size from observed usage.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + `allowed-tools` for internal read-only skills — `probe-cluster-state` allows only read-only `kubectl`).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/k8s-manifests.md
@rules/k8s-security.md
@rules/k8s-resources.md
