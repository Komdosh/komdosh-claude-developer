---
description: Audit all ArgoCD apps for GitOps hygiene — pinned prod revisions, scoped AppProjects, prune+selfHeal on prod, no inline secrets, narrow ignoreDifferences — classified BLOCKER/WARNING/INFO. Read-only.
argument-hint: [--path=<dir>]
---

Run an ArgoCD GitOps-hygiene audit with the `k8s-diagnostician` agent (audit mode).

The agent runs `discover-argocd-apps` and reports every hygiene gap:

- **BLOCKER** — a prod Application tracking a moving revision (`HEAD`/branch); an inline secret value in an app or its tracked values (routes to `secrets-sentinel`); an app in the `default` project on a shared/prod cluster.
- **WARNING** — `prune`/`selfHeal` off on a prod app; an unscoped AppProject (`sourceRepos: "*"` or `destinations: "*"`); an overly broad `ignoreDifferences` that hides real drift.
- **INFO** — missing resources-finalizer; missing sync-wave ordering where dependencies exist.

Output is a BLOCKER/WARNING/INFO report with file:line and concrete impact, plus the single highest-value fix. Read-only — never syncs, sets, or edits.
