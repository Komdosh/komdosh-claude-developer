---
name: infra-safety-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*), Bash(git log:*)
description: Fast grep-based preflight over infrastructure files for the highest-signal safety violations — plaintext secrets, mutable image tags, world-open CIDRs, missing resource limits, over-broad IAM, local Terraform state, unpinned versions, and destroy/replace hazards. Runs in seconds against a diff or a tree; cheaper than a full audit or a `terraform plan`. Returns findings classified BLOCKER/WARNING/INFO with file:line. Read-only. Run before declaring any infra change done, and as the first pass inside the infra-reviewer and secrets-sentinel agents.
---

# Infrastructure Safety Scan

A seconds-long grep sweep that catches the forbidden patterns from `rules/iac-safety.md` and `rules/secrets-hygiene.md` before they reach review or apply. Not a substitute for `terraform plan`, a full audit, or the specialist auditors — it is the cheap first gate that catches the obvious, high-cost mistakes early.

Scope to the diff when reviewing a change (`git diff` against the base branch); scope to the tree when auditing a whole repo. Track as a todo when invoked.

## What it scans for

### Secrets (BLOCKER)
- Assignment-shaped secrets: `password`, `secret`, `token`, `api_key`, `access_key`, `private_key`, `client_secret` set to a non-variable, non-reference literal.
- `-----BEGIN … PRIVATE KEY-----` anywhere in tracked files.
- Kubernetes `kind: Secret` with `data:`/`stringData:` literals in a tracked (non-SOPS, non-sealed) file.
- Committed credential files: `*-key.json` service-account keys, `*.pem`, `kubeconfig`, `.env` with values.
- Report location + secret **type** only — never echo the value (see `rules/secrets-hygiene.md`).

### Mutable/unpinned references (WARNING)
- Image `:latest`, `:main`, `:master`, or an image with no tag in a deployed workload.
- Terraform provider/module without a pinned `version`/`?ref=`; Helm dependency without a pinned `version`.
- ArgoCD `targetRevision: HEAD` / a branch name for a prod Application.

### Network exposure (BLOCKER/WARNING)
- `0.0.0.0/0` or `::/0` in a security-group ingress, NetworkPolicy, or firewall rule — BLOCKER on an admin/DB port (22, 3389, 5432, 6379, 27017, 9200, 2379), WARNING otherwise (confirm it's a genuine public port).
- Kubernetes `hostNetwork: true`, `privileged: true`, `hostPID`/`hostIPC: true`.

### IAM / access (WARNING)
- Wildcard actions/resources (`"*"`), `roles/*admin`, `editor`, or `AdministratorAccess` bindings.
- Terraform `iam` bindings granting broad roles to a service account.

### Reliability / state (WARNING)
- Kubernetes workload with no `resources.requests`/`limits`.
- Local Terraform state: `terraform.tfstate` tracked in git, or a `terraform {}` block with no `backend`.
- Missing `prevent_destroy` on obviously stateful resources (DB instance, disk, bucket) when the diff replaces them.

### Destroy/replace hazards (BLOCKER)
- In a diff: a stateful resource block removed, renamed, or with a changed `for_each`/`count` key.
- Any `-target`, `-auto-approve`, or `terraform destroy` in a committed script/CI without a reviewed gate.

## Method

1. Scope: `git diff <base>...HEAD --name-only` for a change, or glob the tree for an audit. Restrict to infra file types (`*.tf`, `*.tfvars`, `*.yaml`, `*.yml`, `Chart.yaml`, `values*.yaml`, `*.json` under IaC dirs, CI files).
2. Run the pattern families above with `grep -nE`. Keep each pattern tight to avoid noise; a false positive on a secret is cheap, a miss is not.
3. For each hit, capture `file:line`, the matched pattern family, and the concrete impact.

## Output

```
INFRA SAFETY SCAN — <N> findings (<b> blocker, <w> warning, <i> info)

BLOCKER
- <file>:<line>  <family>  — <concrete impact>
WARNING
- <file>:<line>  <family>  — <concrete impact>
INFO
- <file>:<line>  <family>  — <note>

Clean families: <the families that returned nothing>
```

State which families came back empty — a clean verdict needs evidence, not silence. Hand any deep secrets findings to `secrets-sentinel` and any plan-level hazards to the specialist reviewer.
