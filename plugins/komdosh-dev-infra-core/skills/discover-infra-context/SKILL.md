---
name: discover-infra-context
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(find:*), Bash(ls:*), Bash(yc config list:*), Bash(kubectl config:*), Bash(git remote:*)
description: Map an infrastructure repository into a structured descriptor — which IaC tools are present (Terraform/OpenTofu, Kubernetes manifests, Helm, Kustomize, ArgoCD, Ansible), which cloud provider(s), the environment layout (dev/staging/prod overlays or workspaces), state/backend configuration, and which secret-management approach is in use. Read-only. Every infra command and agent runs this once to orient before acting; specialist plugins consume the descriptor rather than re-discovering. Degrades gracefully when tools/CLIs are absent.
---

# Discover Infrastructure Context

Build a structured picture of an infrastructure repository so downstream agents act with full context instead of guessing. Read-only everywhere. Run **once per session**, not repeatedly — cache the descriptor.

Track each step as a todo when invoked.

## Inputs

- `path` (optional) — repo/subdir to map; defaults to the current working directory.
- Any hint the caller passes (`--tool=terraform`, `--env=prod`) narrows the scan but never replaces it.

## Step 1: Detect the IaC tools present

Glob from the root; record which are present and where their roots are:

| Tool | Signal | Root marker |
|---|---|---|
| Terraform / OpenTofu | `*.tf`, `*.tf.json`, `.terraform.lock.hcl` | dir containing `backend`/`terraform {}` block |
| Kubernetes (plain) | `*.yaml` with `apiVersion:` + `kind:` | dir of manifests |
| Kustomize | `kustomization.yaml` | `base/` + `overlays/` layout |
| Helm | `Chart.yaml`, `values*.yaml`, `templates/` | chart dir |
| ArgoCD | manifests with `kind: Application`/`ApplicationSet`/`AppProject` (`argoproj.io`) | apps dir / app-of-apps root |
| Ansible | `playbook*.yaml`, `roles/`, `inventory` | playbook dir |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` | as found |

Do not assume a single tool — real estates mix Terraform (provisioning) + Kubernetes/ArgoCD (delivery). Record all.

## Step 2: Identify the cloud provider(s)

- Terraform: read `required_providers` and `provider` blocks — `yandex-cloud/yandex`, `hashicorp/aws`, `hashicorp/google`, `hashicorp/azurerm`, `kubernetes`, `helm`.
- CLI config (read-only, best-effort): `yc config list` (Yandex Cloud — folder/cloud), `kubectl config current-context`. Absent CLI → skip, don't fail.
- Record provider + version constraints, and whether auth is keyless (metadata/OIDC/workload identity) or key-file based.

## Step 3: Map the environment layout

Determine how environments are separated:

- **Kustomize** — enumerate `overlays/*`.
- **Helm** — enumerate `values-*.yaml`.
- **Terraform** — directory-per-env (`envs/{dev,staging,prod}/`) or workspaces (`terraform workspace list` if available) or `*.tfvars` per env.
- **ArgoCD** — one Application per env, or an ApplicationSet with a generator; note the per-env `targetRevision`/`path`.

Record the env names found and the mechanism. Flag if prod and non-prod share state/namespace/source (a blast-radius smell).

## Step 4: Locate state & secrets handling

- **State**: Terraform `backend` block (type + whether locking/encryption are configured), or local `terraform.tfstate` in the tree (a finding — see `rules/terraform-state-safety.md` in the terraform plugin).
- **Secrets**: presence of External Secrets / Sealed Secrets / SOPS (`.sops.yaml`) / Vault references / ArgoCD Vault Plugin, vs plaintext `Secret`/`.tfvars` in the tree. Record the mechanism; the deep leak audit is `secrets-sentinel`'s job, not this skill's.

## Step 5: Return the descriptor

```json
{
  "root": "<path>",
  "tools": [{ "tool": "terraform|kubernetes|kustomize|helm|argocd|ansible|ci", "roots": ["<path>"], "notes": "…" }],
  "clouds": [{ "provider": "yandex|aws|gcp|azure|none", "versions": "…", "auth": "keyless|key-file|unknown" }],
  "environments": [{ "name": "dev|staging|prod|…", "mechanism": "kustomize-overlay|helm-values|tf-dir|tf-workspace|argocd-app" }],
  "state": { "backend": "s3|gcs|yc-object-storage|local|none", "locking": "yes|no|unknown", "encryption": "yes|no|unknown" },
  "secrets": { "mechanism": "external-secrets|sealed-secrets|sops|vault|avp|plaintext|none", "confidence": "verified|inferred" },
  "recommended_plugin": "infra-terraform|infra-kubernetes|infra-argocd|infra-yandex|infra-core",
  "gaps": ["what a complete infra repo should have but this one is missing"]
}
```

`recommended_plugin` points the caller at the specialist that owns the dominant concern. `gaps` is load-bearing — a Terraform repo with local state, or a k8s repo with plaintext Secrets, surfaces here so the right audit runs next.
