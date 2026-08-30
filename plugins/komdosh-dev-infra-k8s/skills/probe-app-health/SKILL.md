---
name: probe-app-health
user-invocable: false
allowed-tools: Read, Bash(argocd app get:*), Bash(argocd app diff:*), Bash(argocd app history:*), Bash(kubectl get:*), Bash(kubectl describe:*)
description: Read-only probe of a live ArgoCD Application's sync and health state when the argocd CLI or the Application CR is reachable — Synced/OutOfSync, Healthy/Progressing/Degraded/Missing, the out-of-sync resource list, last sync result and message, operation state, conditions, and the resource-level health that explains a Degraded app. Never syncs, sets, or deletes. Degrades to "not reachable — reason from git manifests" when neither the CLI nor the CR is available. Used by k8s-diagnostician.
---

# Probe App Health

Gather the read-only evidence a sync/health diagnosis needs. **Never** mutates ArgoCD or the cluster — only `argocd app get/diff/history` and `kubectl get/describe`.

## 0. Confirm reachability and target

- Try `argocd app get <app> -o json` (CLI authenticated) or read the `Application` CR via `kubectl get application <app> -n argocd -o yaml`.
- Confirm which ArgoCD instance / cluster you're looking at before probing prod.
- Neither reachable → set `reachable: false`, stop, and tell the caller to reason from the git manifests (`discover-argocd-apps`) plus the symptoms given.

## 1. Sync and health headline

From `argocd app get` (or the CR `status`):

- **sync.status**: Synced / OutOfSync, and `sync.revision`.
- **health.status**: Healthy / Progressing / Degraded / Missing / Suspended.
- Remember these are independent: **Synced + Degraded** = git applied but resources unhealthy; **OutOfSync + Healthy** = working but diverged from git.

## 2. What is out of sync / unhealthy

- `status.resources[]` — per-resource sync + health; list the specific resources that are OutOfSync or Degraded (kind/name/namespace).
- `argocd app diff <app>` (read-only) — the actual difference between git desired state and live state; this is the drift, concretely. **Redact any secret values** in the diff — never print them.

## 3. Why the last operation failed

- `status.operationState` — phase (Running/Succeeded/Failed/Error), message, and `syncResult` per resource (the exact apply error: a schema rejection, an immutable-field conflict, a hook failure, an RBAC/AppProject denial).
- `status.conditions[]` — SyncError, ComparisonError, OrphanedResource, and warnings.

## 4. Resource-level cause for Degraded

- For a Degraded app, drill into the failing workload with `kubectl describe`/`get` (read-only) — the app is Degraded because a pod/Service/Ingress underneath is unhealthy. Deep workload diagnosis is `k8s-diagnostician`'s job.

## 5. Recent history

- `argocd app history <app>` — recent synced revisions, to know what "the previous good state" was for a git-revert rollback.

## 6. Return the evidence bundle

```json
{
  "reachable": true,
  "app": "order-service-prod",
  "sync": { "status": "OutOfSync", "revision": "v1.8.3" },
  "health": { "status": "Degraded" },
  "out_of_sync_resources": [{ "kind": "Deployment", "name": "…", "health": "Degraded" }],
  "operation": { "phase": "Failed", "message": "<verbatim sync error, secrets redacted>" },
  "conditions": ["SyncError: …"],
  "diff_summary": "<the drift, values redacted>",
  "last_good_revision": "v1.8.2",
  "notes": "…"
}
```

Evidence, not diagnosis — `k8s-diagnostician` maps it to a root cause and a **git-based** remediation. If `reachable: false`, say so plainly.
