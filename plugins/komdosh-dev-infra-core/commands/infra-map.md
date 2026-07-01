---
description: Map this infrastructure repository — IaC tools, cloud providers, environment layout, state backend, and secret-management approach — and recommend which specialist plugin owns the dominant concern.
argument-hint: [--path=<dir>]
---

Run the `discover-infra-context` skill against the repository (or the `--path=` subtree) and present its descriptor as a readable summary.

Report:
- **Tools** — Terraform/OpenTofu, Kubernetes (plain/Kustomize/Helm), ArgoCD, Ansible, CI — and where each root lives.
- **Cloud(s)** — provider(s) and version constraints, keyless vs key-file auth.
- **Environments** — the dev/staging/prod mechanism (overlays / workspaces / tfvars / ApplicationSet) and any blast-radius smell (prod sharing state/namespace/source with non-prod).
- **State & secrets** — backend type + locking/encryption; secret-management mechanism vs plaintext in the tree.
- **Gaps** — what a complete infra repo should have but this one is missing.
- **Next** — the `recommended_plugin` and the single highest-value action (often "run `secrets-sentinel`" or a specialist audit).

Read-only. This is the orientation step other infra commands run internally; use it standalone to get your bearings in an unfamiliar infra repo.
