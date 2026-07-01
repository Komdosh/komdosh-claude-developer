---
description: Review an infrastructure change across correctness, blast radius, reversibility, security, drift, and cost — grounded in the diff and the rendered plan. Read-only.
argument-hint: [base-branch] [--path=<dir>]
---

Review the current infrastructure change with the `infra-reviewer` agent.

- **base** — the branch to diff against, from the first positional argument; otherwise the repo default (`main`/`develop`). Confirm before diffing if genuinely ambiguous.
- **path** — restrict the review to a subtree if `--path=` is given.

The agent runs `discover-infra-context` and `infra-safety-scan` first, reads the diff (and a read-only render — `terraform plan` output, `kustomize build`, `helm template`, `argocd app diff` — where one is cheaply available), reviews the six dimensions, routes deep findings to the specialist auditors when their plugin is installed, re-scans, and returns a severity-ordered verdict.

Never applies or syncs anything. If the user has provided plan/diff output, use it; do not run `apply`.
