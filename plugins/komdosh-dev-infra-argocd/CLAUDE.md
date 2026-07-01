# CLAUDE.md — komdosh-dev-infra-argocd

ArgoCD GitOps delivery on top of `komdosh-dev-infra-core`. One domain: get changes to the cluster through ArgoCD — pinned, scoped, self-healing, revertible — and diagnose delivery when it breaks, always through git, never by hand.

## What it adds

| Piece | Purpose |
|---|---|
| [`/argo-app <name>`](commands/argo-app.md) | Author an Application / ApplicationSet / AppProject via `argocd-app-author`. |
| [`/argo-diagnose <app>`](commands/argo-diagnose.md) | Root-cause an OutOfSync/Degraded/failing app via `argocd-diagnostician`. |
| [`/argo-audit`](commands/argo-audit.md) | GitOps-hygiene audit of all apps via `argocd-diagnostician` (audit mode). |
| [`argocd-app-author`](agents/argocd-app-author.md) | Writes GitOps-correct delivery manifests; never syncs. |
| [`argocd-diagnostician`](agents/argocd-diagnostician.md) | Read-only sync/health diagnosis + hygiene audit; git-based remediation only. |
| [`discover-argocd-apps`](skills/discover-argocd-apps/SKILL.md) | Inventory apps/appsets/projects, revision pinning, sync policy, waves → descriptor. |
| [`probe-app-health`](skills/probe-app-health/SKILL.md) | Read-only live sync/health evidence (`argocd app get/diff/history`). |
| `rules/*.md` | Two convention documents, imported via `@rules/...` below. |

## Big picture

`argocd-app-author` writes the **delivery wrapper** (the Application/ApplicationSet/AppProject); the workloads it deploys are `k8s-manifest-author`'s job (kubernetes plugin). `argocd-diagnostician` diagnoses delivery read-only and prescribes a **git** fix — never a manual `argocd app sync`/`kubectl edit`, because a manual fix is exactly the drift GitOps exists to prevent. Neither agent mutates ArgoCD or a cluster: authoring lands as a reviewable git PR that ArgoCD syncs; rollback is `git revert`.

The one distinction the diagnostician always draws: **sync status ≠ health status.** A Synced app can be Degraded (git applied, pods crashing); an OutOfSync app can be Healthy (working but diverged). Diagnosing the wrong signal wastes the investigation. A Degraded-from-a-crashing-pod app routes to `k8s-troubleshooter` for the pod-level root cause.

## Conventions imported as rules

- **`argocd-applications.md`** — the Application anatomy that matters (pinned prod `targetRevision`, a scoped `project` never `default`, `automated` sync with `prune`+`selfHeal`, `syncOptions`, resources-finalizer); AppProject as the guardrail (scoped `sourceRepos`/`destinations`, cluster-resource whitelist); ApplicationSet fan-out; app-of-apps with sync waves; narrow `ignoreDifferences`; hooks; secrets never inline.
- **`gitops-delivery.md`** — promotion moves the same artifact in git (a reviewable diff, not a manual sync); image-update options; sync waves for ordering; sync-status vs health-status as two signals; drift auto-healed but investigated; rollback = git revert; break-glass followed same-day by a codifying commit.

## Relationship to the rest of the suite

- **Payload manifests** → `komdosh-dev-infra-kubernetes` (`k8s-manifest-author` writes what ArgoCD deploys; `k8s-troubleshooter` diagnoses the pods under a Degraded app).
- **The cluster ArgoCD runs on** → `komdosh-dev-infra-terraform` / `komdosh-dev-infra-yandex` provision it.
- **Secrets** → `secrets-sentinel` (infra-core) sweeps for inline secret leaks in app manifests.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + read-only `allowed-tools`).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/argocd-applications.md
@rules/gitops-delivery.md
