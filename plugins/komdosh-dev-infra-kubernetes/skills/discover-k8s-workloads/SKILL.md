---
name: discover-k8s-workloads
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(find:*), Bash(kustomize build:*), Bash(helm template:*)
description: Inventory a Kubernetes manifest tree into a structured descriptor — packaging (plain YAML vs Kustomize base/overlays vs Helm chart), workloads (Deployments/StatefulSets/DaemonSets/Jobs) and their images, Services/Ingress, ConfigMaps/Secrets, namespaces, and the per-environment overlay/values layout. Renders Kustomize/Helm read-only to see the effective manifests when possible. Read-only. Run before authoring or auditing manifests so the work fits the existing packaging. Consumed by k8s-manifest-author and k8s-hardening-auditor.
---

# Discover Kubernetes Workloads

Map a Kubernetes manifest tree so downstream work respects the existing packaging and doesn't fight the overlay/values structure. Read-only. Track as a todo when invoked.

## Step 1: Determine the packaging

| Packaging | Signal | Effective manifests |
|---|---|---|
| Plain YAML | loose `*.yaml` with `apiVersion` + `kind` | the files themselves |
| Kustomize | `kustomization.yaml`, `base/` + `overlays/` | `kustomize build overlays/<env>` |
| Helm | `Chart.yaml`, `templates/`, `values*.yaml` | `helm template . -f values-<env>.yaml` |

Render the **effective** manifests read-only where a renderer is cheap (`kustomize build`, `helm template`) — auditing the rendered output catches overlay bugs that source review misses. Never `apply`.

## Step 2: Inventory workloads

For each workload (`Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`) record:

- name, kind, namespace, replicas;
- container images and whether the tag is **immutable** (digest/unique) or **mutable** (`:latest`/branch — a finding);
- presence of probes (startup/readiness/liveness), resources (requests/limits), securityContext;
- the ServiceAccount used (dedicated vs `default`).

Don't audit yet — just record what exists and what's missing. The audit is `k8s-hardening-auditor`'s job.

## Step 3: Networking and config

- **Services** (type: ClusterIP/NodePort/LoadBalancer) and **Ingress**/Gateway — note any `LoadBalancer`/`NodePort` exposure and TLS config.
- **NetworkPolicy** presence (or absence — default-deny missing is a finding).
- **ConfigMap**/**Secret** objects — flag any `Secret` with plaintext `data`/`stringData` in a tracked file (hand to `secrets-sentinel`).

## Step 4: Environments and namespaces

- Enumerate overlays (`overlays/*`) or per-env values (`values-*.yaml`); map each to a namespace/env.
- Flag prod and non-prod sharing a namespace or lacking isolation.

## Step 5: Return the descriptor

```json
{
  "packaging": "plain|kustomize|helm",
  "render_cmd": "kustomize build overlays/prod | helm template … | n/a",
  "namespaces": ["…"],
  "environments": [{ "name": "prod", "mechanism": "overlay|values", "namespace": "…" }],
  "workloads": [{ "name": "…", "kind": "Deployment", "image_mutable": false, "has_probes": true, "has_resources": false, "security_context": "restricted|partial|none", "service_account": "dedicated|default" }],
  "networking": { "services": ["…"], "ingress": ["…"], "network_policy": "present|absent", "external_exposure": ["LoadBalancer svc X"] },
  "secrets_in_tree": ["<file>:<line> plaintext Secret"],
  "gaps": ["workload X has no resources", "no NetworkPolicy in ns Y", "mutable image on Z"]
}
```

`gaps` seeds the hardening audit; `secrets_in_tree` routes to `secrets-sentinel`.
