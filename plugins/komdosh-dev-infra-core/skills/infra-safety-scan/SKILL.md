---
name: infra-safety-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*), Bash(git log:*)
description: Fast grep-based preflight over infrastructure files for the highest-signal safety violations — plaintext secrets, mutable image tags, world-open CIDRs, missing resource limits, over-broad IAM, local Terraform state, unpinned versions, and destroy/replace hazards. Runs in seconds against a diff or a tree; cheaper than a full audit or a `terraform plan`. Returns findings classified BLOCKER/WARNING/INFO with file:line. Read-only. Run before declaring any infra change done, and as the first pass inside the infra-reviewer and secrets-sentinel agents.
---

# Infra Safety Scan

A seconds-long sweep for the forbidden patterns in `rules/iac-safety.md` and `rules/secrets-hygiene.md`, before review or apply. **Not a substitute** for a plan or a full audit — the cheap first gate that catches the expensive mistakes early.

Scope to the diff when reviewing a change, to the tree when auditing. **A false positive is cheap here; a miss is not** — keep patterns tight enough to stay readable, loose enough to catch.

## Families

**Secrets — BLOCKER.** Assignment-shaped `password`/`secret`/`token`/`api_key`/`access_key`/`private_key`/`client_secret` set to a literal · `BEGIN … PRIVATE KEY` in any tracked file · a `kind: Secret` with `data:`/`stringData:` literals in a tracked non-SOPS, non-sealed file · committed credential files (`*-key.json`, `*.pem`, `kubeconfig`, a valued `.env`).
**Report location and secret type only — never the value.**

**Mutable / unpinned — WARNING.** `:latest`/`:main`/`:master`/untagged images · providers, modules, or Helm dependencies with no pinned `version`/`?ref=` · `targetRevision: HEAD` or a branch on a prod Application.

**Network exposure.** `0.0.0.0/0` or `::/0` in an ingress, NetworkPolicy, or firewall rule — **BLOCKER on an admin or database port** (22, 3389, 5432, 6379, 27017, 9200, 2379), WARNING elsewhere pending confirmation that it's genuinely public · `hostNetwork`, `privileged`, `hostPID`/`hostIPC`.

**IAM — WARNING.** Wildcard actions or resources · `roles/*admin`, `editor`, `AdministratorAccess` bound to a service account.

**Reliability and state — WARNING.** A workload with no requests/limits · `terraform.tfstate` tracked in git, or a `terraform {}` block with no `backend` · a stateful resource being replaced without `prevent_destroy`.

**Destroy/replace hazards — BLOCKER.** In a diff: a stateful resource block removed, renamed, or with a changed `for_each`/`count` key · `-target`, `-auto-approve`, or `destroy` in a committed script or CI job without a reviewed gate.

## Output

`file:line`, family, and the concrete impact, grouped BLOCKER / WARNING / INFO.

**State which families came back empty** — a clean verdict needs evidence, not silence. Hand deep secrets findings to `secrets-sentinel` and plan-level hazards to the specialist reviewer.
