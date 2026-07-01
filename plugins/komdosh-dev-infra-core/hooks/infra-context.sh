#!/usr/bin/env bash
# SessionStart hook: detect whether the current repo is an infrastructure repo
# (Terraform/OpenTofu, Helm, Kustomize, or ArgoCD) and, if so, inject a one-time
# orientation plus a pointer to the safety discipline as additionalContext — so an
# infra session starts knowing the plan→review→apply contract and the secrets rule
# without spending a discover-infra-context invocation up front.
#
# Silent no-op in non-infra repos. Bounded, millisecond-scale (maxdepth-limited,
# stops at the first marker). Emits SessionStart JSON additionalContext on stdout;
# never blocks session start.

set -uo pipefail

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v jq >/dev/null 2>&1 || exit 0

tools=""
# File-marker detection: -print -quit stops at the first hit (no pipelines under pipefail).
if [ -n "$(find "$project_root" -maxdepth 5 -name '*.tf' -print -quit 2>/dev/null)" ]; then
  tools="${tools}Terraform/OpenTofu "
fi
if [ -n "$(find "$project_root" -maxdepth 5 -name 'Chart.yaml' -print -quit 2>/dev/null)" ]; then
  tools="${tools}Helm "
fi
if [ -n "$(find "$project_root" -maxdepth 5 -name 'kustomization.yaml' -print -quit 2>/dev/null)" ]; then
  tools="${tools}Kustomize "
fi
if grep -rqlE 'argoproj\.io' --include='*.yaml' --include='*.yml' "$project_root" 2>/dev/null; then
  tools="${tools}ArgoCD "
fi

# Not an infra repo (plugin may be installed user-scope) → stay silent.
[ -n "$tools" ] || exit 0

ctx="Infrastructure context (auto-injected by komdosh-dev-infra-core SessionStart hook). Detected: ${tools}.

Before changing real infrastructure, follow the plan → review → apply contract:
1. Render desired state (terraform plan · kustomize build · helm template · argocd app diff) and read it.
2. Review blast radius — what is created / updated / REPLACED / DESTROYED; what is stateful; what is irreversible.
3. Apply only the exact reviewed artifact. Never -auto-approve an unseen plan; never kubectl apply against a GitOps-managed cluster.

Non-negotiables: no plaintext secrets in git (base64 is not encryption); pin every image/provider/chart/module version; set resource requests+limits; no 0.0.0.0/0 on admin/DB ports. Personal data (PII) is encrypted at rest (KMS) + in transit, kept off logs/public buckets, residency-bound (RU personal data in ru-central1 per 152-FZ; EU-subject data not moved to RU without a GDPR transfer basis), and deletable. Run infra-safety-scan + pii-exposure-scan on the diff, and secrets-sentinel for a leak sweep, before declaring an infra change done."

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}, suppressOutput: true}'

exit 0
