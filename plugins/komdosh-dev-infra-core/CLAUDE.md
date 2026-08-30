# komdosh-dev-infra-core

The shared safety, secrets, promotion, and data-protection discipline every infra plugin builds on. No cloud or language assumptions.

| Plugin | Adds |
|---|---|
| `komdosh-dev-infra-iac` | Terraform/OpenTofu authoring, plan-safety analysis, state discipline — with the Yandex Cloud layer built in |
| `komdosh-dev-infra-k8s` | Hardened manifests, workload troubleshooting, and ArgoCD GitOps delivery |

Composes with, but doesn't depend on, the Kotlin/Spring suite: core's `rules/local-dev.md` writes a service's own Dockerfile and Compose; **this suite owns the estate those images deploy into.**

## One contract, three enforcement points

Every infra action obeys `rules/iac-safety.md`: **render the desired state → review the blast radius → apply only the reviewed artifact.**

- `discover-infra-context` orients first — which tools, clouds, environments exist — so nothing acts blind. **Once per session.**
- `infra-safety-scan` is the cheap gate: a grep sweep before declaring any infra change done.
- The three agents are the deep passes — `infra-reviewer` on a *change*, `secrets-sentinel` on *secrets*, `data-protection-auditor` on *personal data*.

**The agents route rather than overreach.** A Terraform state hazard goes to `iac-reviewer`, a Pod Security violation to `k8s-auditor`, a sync failure to `k8s-diagnostician`; residency specifics go to `iac-reviewer`, credential leaks to `secrets-sentinel`, and app-layer PII-in-code to the Spring suite's `/pii-leakage-check`.

All three are read-only **at the tool layer** (`disallowedTools`), not merely by convention — they report, the specialist authors change. The recommended permission set keeps every mutating infra command behind an explicit human decision.

@rules/iac-safety.md
@rules/secrets-hygiene.md
@rules/gitops-principles.md
@rules/environment-promotion.md
@rules/infra-review.md
@rules/pii-data-protection.md
