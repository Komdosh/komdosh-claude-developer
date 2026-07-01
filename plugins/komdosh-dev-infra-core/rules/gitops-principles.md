# GitOps Principles

GitOps means the desired state of a system lives in git, and an automated controller continuously reconciles the running system toward it. Four properties define it; every infra decision either upholds them or is a smell.

## The four properties

1. **Declarative** — the system is described by its desired end state, not by the imperative steps to reach it. Manifests, HCL, and Helm values say *what*, not *how*.
2. **Versioned and immutable** — the desired state is stored in git. Every change is a commit; history is the audit log; a bad change is reverted, not hot-patched.
3. **Pulled automatically** — a controller (ArgoCD, Flux, a CI apply gate) pulls approved changes from git. Humans change git; the controller changes the cluster.
4. **Continuously reconciled** — the controller detects drift between git and reality and corrects it (self-heal), so the running system cannot silently diverge from the source of truth.

## What this forbids

- **No out-of-band changes.** `kubectl edit`, console click-ops, and manual `apply` against a GitOps-managed target create drift the controller will fight, revert, or alarm on. If you must break glass in an incident, the follow-up is a commit that codifies the change (or a revert), same day.
- **No "git is the source of truth, except…".** Partial GitOps (some apps synced, some hand-managed) means nobody knows which is which. Either a resource is reconciled from git or it is explicitly, documentedly out of scope.
- **No moving targets in production.** A production Application/deploy that tracks a mutable branch (`main`, `HEAD`) or a mutable image tag has no stable desired state — the "desired state" changes without a commit. Pin: a tag, a digest, or a specific revision, promoted deliberately.

## Source of truth vs deployment mechanics

Keep two things separate and consistent:

- **Source of truth** = the git repo + path + revision the controller reads. There is exactly one per environment per app.
- **Promotion** = how a change moves from dev to prod (a commit to an env overlay, a bumped image tag in an env values file, an ApplicationSet generator). Promotion is a git operation, reviewable as a diff. See `rules/environment-promotion.md`.

## Rollback is a git operation

The correct rollback in GitOps is `git revert` (or re-pointing to the previous pinned revision) followed by a sync. This is why immutability matters: reverting the desired state is only meaningful if the artifacts it references still exist and are unchanged. Never "roll back" by editing the cluster directly — that just adds drift on top of a bad state.

## Drift is a signal, not noise

When the controller reports drift (OutOfSync, a resource differs from git), something changed reality without changing git. Investigate the cause — a manual change, a mutating admission webhook, a controller writing status into spec — before blindly re-syncing. Auto-heal handles benign drift; unexplained drift is an incident lead.
