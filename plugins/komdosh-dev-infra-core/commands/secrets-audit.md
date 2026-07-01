---
description: Sweep the repository for exposed secrets across every infrastructure layer (Terraform, Kubernetes, Helm, ArgoCD, CI, credential files). Reports leaks by file:line and type — never the value. Read-only.
argument-hint: [--diff=<base>] [--path=<dir>]
---

Invoke the `secrets-sentinel` agent to hunt for exposed secrets.

- Default scope is the whole repository (or the `--path=` subtree).
- `--diff=<base>` narrows the sweep to the change against `<base>` — use this as a pre-commit gate.

The agent sweeps Terraform literals/tfvars/state exposure, plaintext Kubernetes Secrets (base64 is not encryption), Helm values, ArgoCD manifests, CI files, and committed credential files (service-account keys, `.pem`, `kubeconfig`, `.env`). It classifies confirmed vs suspected, notes whether a leak persists in git history, and returns rotation-first remediation.

It never prints a secret's value and never modifies files. Rotation and migration to a secret store are recommended for a human to execute, not performed.
