# ArgoCD Application Conventions

`Application`, `ApplicationSet`, and `AppProject` are themselves manifests in git and obey the same GitOps and secrets rules as anything else.

## The load-bearing Application fields

- **`spec.source.targetRevision`** — **pinned in production** to a tag, SHA, or chart version. Tracking `HEAD` or a branch means the desired state moves without a commit. Lower environments may track a branch for velocity; prod must not.
- **`spec.project`** — a purpose-built `AppProject`, **never `default`**. The project is the security boundary.
- **`syncPolicy.automated.prune` + `selfHeal`** — together they make the app genuinely GitOps: prune removes what git removed, selfHeal reverts manual cluster edits. **Leaving selfHeal off invites silent drift.**
- **`syncOptions`** — `CreateNamespace` for the first sync, `ApplyOutOfSyncOnly` to cut churn, `ServerSideApply` for large CRDs and shared field ownership.
- **`finalizers: [resources-finalizer.argocd.argoproj.io]`** — without it, **deleting the Application orphans everything it managed.**
- A `retry` with backoff, so a transient failure doesn't need a human.

## AppProject is the guardrail

It whitelists which repos, destinations, and resource kinds the app may touch. **`sourceRepos: ["*"]` and a wildcard destination defeat the entire point** — scope both, deny cluster-scoped resources by default.

## ApplicationSet

Generates apps across environments, clusters, or tenants from a generator. **Keep `targetRevision` per-entry** — prod pinned, non-prod free — and advancing a generator entry becomes the promotion, reviewable as a diff.

## App-of-apps and sync waves

A root Application over a directory of child Applications bootstraps many at once. **Order them with `argocd.argoproj.io/sync-wave`** so namespaces, CRDs, and secret operators land before the workloads that need them.

## ignoreDifferences and hooks

`ignoreDifferences` suppresses fields a controller mutates (HPA-managed `replicas`, webhook-injected values) so the app doesn't sit permanently OutOfSync — **scope it narrowly, because a broad ignore hides real drift.** Resource hooks (`PreSync`/`Sync`/`PostSync`) run migrations and smoke checks; set a `hook-delete-policy` so hook pods clean up.

## Secrets

ArgoCD renders what is in git, so **a secret value in an Application or its tracked values is a plaintext leak.** Consume via the Vault Plugin, External Secrets, or Sealed Secrets.
