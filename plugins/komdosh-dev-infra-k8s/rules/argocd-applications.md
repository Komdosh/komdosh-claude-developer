# ArgoCD Application Conventions

How to declare ArgoCD `Application`, `ApplicationSet`, and `AppProject` resources so delivery is pinned, scoped, self-healing, and reversible. These CRs are themselves manifests in git — they obey the same GitOps and secrets rules as anything else (infra-core `rules/gitops-principles.md`, `rules/secrets-hygiene.md`).

## Application — the anatomy that matters

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service-prod
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # cascade-delete managed resources on app deletion
spec:
  project: commerce                              # a real AppProject, never "default"
  source:
    repoURL: https://git.example.com/infra/gitops.git
    path: apps/order-service/overlays/prod
    targetRevision: v1.8.3                        # PINNED — a tag/commit/digest, never HEAD/main for prod
  destination:
    server: https://kubernetes.default.svc
    namespace: order-service
  syncPolicy:
    automated:
      prune: true                                # remove resources deleted from git
      selfHeal: true                             # revert out-of-band cluster changes
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff: { duration: 5s, factor: 2, maxDuration: 3m }
```

### The load-bearing fields

- **`spec.source.targetRevision`** — for **production, pin it**: a tag, commit SHA, or chart version. Tracking `HEAD`/a branch means the desired state moves without a commit (see infra-core `rules/gitops-principles.md`). Lower environments may track a branch for velocity; prod must not.
- **`spec.project`** — a purpose-built `AppProject`, never `default`. The project is the security boundary: it whitelists which repos, destinations (clusters/namespaces), and resource kinds the app may touch.
- **`syncPolicy.automated.prune` + `selfHeal`** — together they make the app truly GitOps: prune deletes what git removed; selfHeal reverts manual cluster edits. Prod apps should have both on; leaving selfHeal off invites silent drift.
- **`syncOptions`** — `CreateNamespace` for first sync; `ApplyOutOfSyncOnly` to reduce churn; `ServerSideApply` for large CRDs and shared-field ownership.
- **`finalizers`** — the resources-finalizer makes deleting the Application cascade to its managed resources; without it, deleting the app orphans them.

## AppProject — the guardrail

Every app belongs to an AppProject that constrains it:

```yaml
kind: AppProject
spec:
  sourceRepos: ["https://git.example.com/infra/gitops.git"]   # not "*"
  destinations:
    - server: https://kubernetes.default.svc
      namespace: order-service                                # not "*"
  clusterResourceWhitelist: []                                # deny cluster-scoped by default
  namespaceResourceBlacklist:
    - { group: "", kind: ResourceQuota }
```

`sourceRepos: ["*"]` and `destinations: [{server: "*", namespace: "*"}]` defeat the point — scope them.

## ApplicationSet — many apps from one template

Use an `ApplicationSet` to generate apps across environments/clusters/tenants from a generator (list, git directory, cluster, matrix). Keep the template's `targetRevision` per-env: prod entries pinned, non-prod may track a branch. An ApplicationSet is the promotion mechanism when a change moves by advancing a generator entry — reviewable as a diff.

## App-of-apps

A root Application whose `source` is a directory of child Applications lets one sync bootstrap many. Order child syncs with **sync waves** (`argocd.argoproj.io/sync-wave` annotation) so dependencies (namespaces, CRDs, secrets operators) land before the workloads that need them.

## ignoreDifferences and hooks

- **`ignoreDifferences`** — suppress diffs on fields a controller mutates (HPA-managed `replicas`, webhook-injected fields) so the app doesn't sit perpetually OutOfSync. Scope it narrowly; a broad ignore hides real drift.
- **Resource hooks** — `PreSync`/`Sync`/`PostSync` (annotations) for migrations and smoke checks; set a `hook-delete-policy` so hook pods clean up.

## Secrets

ArgoCD renders what's in git. A secret value in an Application or its tracked values is a plaintext leak. Consume secrets via the ArgoCD Vault Plugin, External Secrets, or Sealed Secrets — never inline (infra-core `rules/secrets-hygiene.md`).
