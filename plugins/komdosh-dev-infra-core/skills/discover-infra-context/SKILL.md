---
name: discover-infra-context
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(find:*), Bash(ls:*), Bash(yc config list:*), Bash(kubectl config:*), Bash(git remote:*)
description: Map an infrastructure repository into a structured descriptor — which IaC tools are present (Terraform/OpenTofu, Kubernetes manifests, Helm, Kustomize, ArgoCD, Ansible), which cloud provider(s), the environment layout (dev/staging/prod overlays or workspaces), state/backend configuration, and which secret-management approach is in use. Read-only. Every infra command and agent runs this once to orient before acting; specialist plugins consume the descriptor rather than re-discovering. Degrades gracefully when tools/CLIs are absent.
---

# Discover Infrastructure Context

Read-only. **Run once per session** and cache the descriptor — every infra agent consumes it rather than re-discovering.

## 1. Tools

| Tool | Signal |
|---|---|
| Terraform / OpenTofu | `*.tf`, `.terraform.lock.hcl` — root is the dir with the `terraform {}` block |
| Kubernetes | YAML with `apiVersion:` + `kind:` |
| Kustomize | `kustomization.yaml`, `base/` + `overlays/` |
| Helm | `Chart.yaml`, `values*.yaml`, `templates/` |
| ArgoCD | `argoproj.io` `Application`/`ApplicationSet`/`AppProject` |
| Ansible | `playbook*.yaml`, `roles/`, `inventory` |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |

**Never assume a single tool.** Real estates mix Terraform for provisioning with Kubernetes/ArgoCD for delivery. Record all of them and their roots.

## 2. Clouds

From `required_providers` and `provider` blocks, plus a best-effort read-only `yc config list` / `kubectl config current-context`. **A missing CLI is skipped, never a failure.** Record the provider, its version constraints, and whether auth is keyless or key-file based.

## 3. Environments

Kustomize overlays · Helm `values-*` · Terraform directory-per-env, workspaces, or per-env tfvars · ArgoCD app-per-env or a generator with per-env `targetRevision`.

**Flag prod and non-prod sharing state, namespace, or source** — that is a blast-radius smell worth surfacing before anything acts.

## 4. State and secrets

State: the backend type and whether locking and encryption are configured — or a local `terraform.tfstate` in the tree, which is itself a finding. Secrets: which mechanism is in use (External Secrets, Sealed Secrets, SOPS, Vault, ArgoCD Vault Plugin) versus plaintext in the tree. **The deep leak audit is `secrets-sentinel`'s job, not this skill's** — record the mechanism and move on.

## 5. Descriptor

```json
{
  "root": "…",
  "tools": [{ "tool": "terraform|kubernetes|kustomize|helm|argocd|ansible|ci", "roots": [], "notes": "" }],
  "clouds": [{ "provider": "yandex|aws|gcp|azure|none", "versions": "", "auth": "keyless|key-file|unknown" }],
  "environments": [{ "name": "", "mechanism": "kustomize-overlay|helm-values|tf-dir|tf-workspace|argocd-app" }],
  "state":   { "backend": "s3|gcs|yc-object-storage|local|none", "locking": "yes|no|unknown", "encryption": "yes|no|unknown" },
  "secrets": { "mechanism": "external-secrets|sealed-secrets|sops|vault|avp|plaintext|none", "confidence": "verified|inferred" },
  "recommended_plugin": "komdosh-dev-infra-iac | komdosh-dev-infra-k8s | komdosh-dev-infra-core",
  "gaps": []
}
```

**`gaps` is load-bearing** — a Terraform repo on local state, or a k8s repo with plaintext Secrets, surfaces here so the right audit runs next.
