---
description: Diagnose an ArgoCD Application that is OutOfSync, Degraded, failing to sync, or drifting — root cause from read-only evidence, with a git-based remediation. Never syncs or edits.
argument-hint: <app-name> [--context=<argocd-ctx>]
---

Invoke the `argocd-diagnostician` agent to diagnose `$ARGUMENTS`.

The agent gathers read-only evidence via `probe-app-health` (sync + health status, out-of-sync resources, the exact sync error, the app diff, conditions, history), separates **sync status** (does the cluster match git?) from **health status** (do the resources work?), finds the actual root cause — a bad manifest, an immutable-field conflict, a failed hook, an AppProject denial, or a controller causing perpetual drift — and prescribes a **git** remediation a human merges and ArgoCD syncs.

It never runs `argocd app sync/set/rollback` or `kubectl edit`, and never chains a manual workaround to hide the symptom. A Degraded app caused by a crashing pod is routed to `k8s-troubleshooter` (if the kubernetes plugin is installed). If ArgoCD isn't reachable, it reasons from the git manifests plus your symptoms and says so.
