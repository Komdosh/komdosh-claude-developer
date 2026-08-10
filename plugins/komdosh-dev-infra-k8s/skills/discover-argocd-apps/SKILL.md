---
name: discover-argocd-apps
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(find:*), Bash(argocd app list:*), Bash(argocd proj list:*)
description: Inventory ArgoCD resources into a structured descriptor — Applications, ApplicationSets, and AppProjects; each app's source (repoURL/path/targetRevision) and whether prod tracks a pinned revision vs a moving branch; destination cluster/namespace; sync policy (automated prune/selfHeal, syncOptions); app-of-apps structure and sync waves; and project scoping. Reads the manifests in git; optionally lists live apps read-only if the argocd CLI is authenticated. Read-only. Run before authoring or auditing ArgoCD resources. Consumed by k8s-author and k8s-diagnostician.
---

# Discover ArgoCD Apps

Map the ArgoCD delivery layer so downstream work fits the existing app structure and project scoping. Read-only. Track as a todo when invoked.

## Step 1: Find the ArgoCD resources in git

- Glob YAML for `kind: Application`, `kind: ApplicationSet`, `kind: AppProject` under `argoproj.io`.
- Identify the **app-of-apps root** (an Application whose `source.path` is a directory of other Applications) if present.

## Step 2: Per-Application facts

For each Application record:

- **source**: `repoURL`, `path`, `targetRevision` — and classify the revision as **pinned** (tag/SHA/chart version) or **moving** (`HEAD`/branch). Moving on a prod app is a finding (infra-core `rules/gitops-principles.md`).
- **destination**: `server` (cluster) + `namespace`.
- **project**: the AppProject — flag `default` (unscoped) as a finding.
- **syncPolicy**: is `automated` set? are `prune` and `selfHeal` both on? which `syncOptions`? Missing selfHeal on prod invites drift.
- **finalizers**: resources-finalizer present (cascading delete) or absent.
- **ignoreDifferences**: present and how broad (a wide ignore hides real drift).
- Any **secret value inline** in the app or its tracked values (route to `secrets-sentinel`).

## Step 3: ApplicationSets

- Generator type (list / git / cluster / matrix / pull-request) and what it fans out over.
- The template's per-env `targetRevision` — are prod-generated apps pinned while non-prod track a branch?

## Step 4: AppProjects — the guardrails

For each project: `sourceRepos`, `destinations`, `clusterResourceWhitelist`/blacklist, `namespaceResourceBlacklist`. Flag `*` in sourceRepos or destinations (defeats scoping).

## Step 5: Sync waves & environments

- Map `argocd.argoproj.io/sync-wave` annotations to see rollout ordering (CRDs/namespaces/operators before workloads).
- Map apps to environments and confirm prod/non-prod separation (distinct projects/namespaces/clusters).

## Step 6: (Optional) live view

If the `argocd` CLI is authenticated, `argocd app list` / `argocd proj list` read-only to reconcile git with what's actually registered. If not authenticated, skip — never assume live state.

## Step 7: Return the descriptor

```json
{
  "apps": [{ "name": "…", "project": "commerce|default", "repoURL": "…", "path": "…", "targetRevision": "v1.8.3", "revision_pinned": true, "auto_sync": true, "prune": true, "self_heal": true, "finalizer": true, "env": "prod" }],
  "appsets": [{ "name": "…", "generator": "git|list|cluster|matrix", "prod_pinned": true }],
  "projects": [{ "name": "commerce", "source_repos_scoped": true, "destinations_scoped": true }],
  "app_of_apps_root": "<name or null>",
  "sync_waves": [{ "app": "…", "wave": 0 }],
  "secrets_inline": ["<file>:<line>"],
  "gaps": ["prod app X tracks HEAD", "app Y in default project", "selfHeal off on Z"]
}
```

`gaps` seeds `/argo-audit`; `secrets_inline` routes to `secrets-sentinel`.
