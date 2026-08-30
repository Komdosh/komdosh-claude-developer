# Terraform State Safety

State maps code to real resources, holds secrets in cleartext, and can orphan or destroy infrastructure when corrupted.

## Remote, locked, encrypted — always

Local state in a shared repo is a defect: concurrent applies corrupt it, it lives on one laptop, and it reaches git with secrets inside.

Every team state needs a **remote backend**, **locking** so applies can't race, **encryption at rest** with restricted read access, and **one state per lifecycle + environment** (`prod/network`, `prod/data`, `staging/app`). One giant state is one blast radius and a slow, risky plan.

## Secrets live in state — plan for it

Terraform writes resource attributes, passwords included, to state in cleartext; `sensitive = true` only redacts CLI output. Encrypt the backend, lock down who can read it, and **prefer reading secrets at apply time from a secret store** so fewer persist in state. Never commit state; never paste its contents anywhere.

## Never hand-mutate state

These are where irreversible mistakes happen, and **the agents here never run them**:

- **`state rm` / `state mv`** — a wrong key silently orphans or clobbers real infrastructure.
- **`import`** — deliberate only, with the config written first, and verified by a plan that shows **no changes** afterward.
- **Editing the state JSON** — never.

## `-target` is a smell, not a tool

It applies a partial graph, leaving state and reality inconsistent with the code. An incident-recovery escape hatch. **Reaching for it routinely means the state is too big — split it.**

## Drift

`plan` surfaces drift as unexpected diffs. **Investigate the cause before applying it away** — blindly reverting a manual prod change can cause the outage. Never destroy to "clean up" drift without knowing exactly what goes.

## `prevent_destroy` on anything holding data

Databases, disks, buckets. It turns an accidental destroy or replace into a plan error instead of data loss, and **removing the guard becomes its own reviewable act.**
