# GitOps Delivery with ArgoCD

How changes reach the cluster through ArgoCD, and how they're rolled back. This operationalises infra-core's `rules/gitops-principles.md` and `rules/environment-promotion.md` for ArgoCD specifically. The governing rule: **the cluster is changed only by ArgoCD syncing what's in git — never by hand.**

## Promotion moves an artifact in git

A change reaches production by a **git operation**, reviewable as a diff:

- Bump the image tag/digest in the prod overlay's values, or
- Advance the pinned `targetRevision` of the prod Application, or
- Advance a prod entry in an ApplicationSet generator.

The image that ran in staging is the image promoted to prod — the **same digest**, not a rebuild (infra-core `rules/environment-promotion.md`). ArgoCD then syncs the change. A human running `argocd app sync` with an overridden image, or `kubectl set image`, is not promotion — it's unreviewed drift.

## Image updates

- **Manual bump** (a PR that edits the tag) — most auditable; the diff is the record.
- **Argo CD Image Updater** — can auto-bump tags matching a constraint and write back to git. Fine for lower envs; for prod, prefer a reviewed PR so a human gates the change.
- Either way the source of truth stays in git; never let the updater write directly to the cluster.

## Sync waves order a rollout

Within an app or an app-of-apps, `argocd.argoproj.io/sync-wave` orders resources: lower waves first. Use it so prerequisites land before dependents — CRDs before the CRs that use them, a namespace + secret operator before the workload, a database migration hook (`PreSync`) before the app that expects the new schema.

## Health and sync status are two different signals

- **Sync status** (Synced / OutOfSync) — does the cluster match git?
- **Health status** (Healthy / Progressing / Degraded / Missing) — are the resources actually working? A Deployment can be **Synced but Degraded** (git applied, pods crashing).

A green sync is not a green deploy. Confirm both, and rely on custom health checks for CRDs ArgoCD doesn't natively understand.

## Drift is auto-healed — and investigated

With `selfHeal: true`, ArgoCD reverts out-of-band cluster changes back to git. That's the desired default, but a recurring OutOfSync is a signal: something keeps changing reality outside git (a manual edit, a mutating webhook, a controller writing into spec). Investigate the cause before dismissing it — auto-heal fixes the symptom, not the source (infra-core `rules/gitops-principles.md`).

## Rollback is git revert

To roll back: **revert the git change** (or re-point `targetRevision` to the previous pinned revision) and let ArgoCD sync. This is why immutability matters — reverting the desired state only works if the previously-referenced artifacts still exist unchanged. Never "roll back" by editing the cluster or by `argocd app rollback` to a history entry that no longer matches git; that just adds drift on top of a bad state. Because promotion was a reviewed diff, the revert is one too.

## Break-glass

In a real incident you may sync/patch the cluster directly to stop the bleeding. The rule is: the same-day follow-up is a commit that codifies the fix (or reverts the bad change), so git converges back to reality. An undocumented manual change that outlives the incident is exactly the drift GitOps exists to prevent.
