# GitOps Delivery with ArgoCD

**The cluster is changed only by ArgoCD syncing what is in git — never by hand.**

## Promotion is a git operation

Bump the digest in the prod overlay, advance the prod Application's pinned `targetRevision`, or advance a prod entry in a generator. **The same digest that ran in staging is promoted — never a rebuild.**

A human running `argocd app sync` with an overridden image, or `kubectl set image`, is not promotion. It is unreviewed drift.

## Image updates

A manual PR bump is the most auditable — the diff is the record. Argo CD Image Updater is fine for lower environments; **for prod prefer a reviewed PR so a human gates the change.** Either way the source of truth stays in git; the updater never writes to the cluster.

## Sync waves order the rollout

Lower waves first, so prerequisites land before dependents: CRDs before their CRs, a namespace and secret operator before the workload, a `PreSync` migration hook before the app that expects the new schema.

## Sync status and health status are different signals

**Sync** answers "does the cluster match git". **Health** answers "do the resources work". A Deployment can be **Synced and Degraded** — git applied cleanly, pods are crashing.

**A green sync is not a green deploy.** Confirm both, and add custom health checks for CRDs ArgoCD doesn't natively understand.

## Drift is auto-healed *and* investigated

`selfHeal` reverting out-of-band changes is the right default, but **a recurring OutOfSync is a signal**: something keeps changing reality outside git — a manual edit, a mutating webhook, a controller writing into spec. Auto-heal fixes the symptom, not the source.

## Rollback is `git revert`

Revert the change, or re-point `targetRevision` to the previous pinned revision, and let ArgoCD sync. **This only works because artifacts are immutable.** Never roll back by editing the cluster, or by `argocd app rollback` to a history entry that no longer matches git — that stacks drift on a bad state. Promotion was a reviewed diff, so the revert is one too.

## Break-glass

In a real incident, patching the cluster directly to stop the bleeding is allowed. **The same-day follow-up is a commit that codifies or reverts it**, so git converges back to reality. An undocumented manual change that outlives the incident is exactly the drift GitOps exists to prevent.
