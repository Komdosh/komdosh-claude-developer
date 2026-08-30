# GitOps Principles

The desired state lives in git; a controller continuously reconciles reality toward it. Four properties: **declarative** (what, not how) · **versioned and immutable** (history is the audit log; a bad change is reverted, not hot-patched) · **pulled** (humans change git, the controller changes the cluster) · **continuously reconciled** (drift is detected and corrected).

## What that forbids

- **Out-of-band changes.** `kubectl edit`, console click-ops, and a manual `apply` against a managed target create drift the controller will fight or revert. Breaking glass in an incident is followed by a commit that codifies or reverts it — same day.
- **Partial GitOps.** "Git is the source of truth, except…" means nobody knows which resources are which. A resource is either reconciled from git or explicitly, documentedly out of scope.
- **A moving target in production.** An Application tracking a mutable branch or a mutable image tag has no stable desired state — it changes without a commit. Pin a tag, digest, or revision and promote it deliberately.

## Source of truth vs. promotion

**Source of truth** is the repo + path + revision the controller reads: exactly one per app per environment. **Promotion** is how a change moves between environments — always a git operation, reviewable as a diff (`rules/environment-promotion.md`). Keep the two separate.

## Rollback is `git revert`

Revert the desired state and sync. That only works because artifacts are immutable — reverting to a revision is meaningless if what it references has changed underneath. **Never "roll back" by editing the cluster**; that stacks drift on top of a bad state.

## Drift is a signal

Drift means something changed reality without changing git. Investigate the cause — a manual change, a mutating webhook, a controller writing into spec — **before re-syncing**. Self-heal handles benign drift; unexplained drift is an incident lead.
