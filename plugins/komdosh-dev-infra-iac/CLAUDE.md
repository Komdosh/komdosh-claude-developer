# komdosh-dev-infra-iac

Terraform/OpenTofu authoring and review on top of `komdosh-dev-infra-core`, with the Yandex Cloud resource layer built in. One domain: **provision infrastructure as code safely and reviewably, and never apply an unread plan.**

## Why one plugin and two agents

`iac-author` writes; `iac-reviewer` critiques. **They never overlap.** Both run `discover-terraform-layout` first so work fits the repo that exists, and both pick up the YC layer (`discover-yc-context`, the `yc-*` rules) when the `yandex` provider is present.

**Yandex Cloud is a provider specialization, not a separate discipline** — the same two agents, the same plan contract, with YC resource semantics and audit families layered on. Splitting it four ways would have broken the who-writes / who-reviews boundary for no gain.

## The plan is the source of truth

`iac-reviewer` anchors on `verify-plan-safety` because **destroys and replaces hide in the plan, not the source** — a source diff that looks purely additive can produce a `-/+` that destroys a database.

Neither agent ever runs `apply`, `destroy`, or a state-mutating command. Those are human decisions the agents enable by producing a reviewed plan. `prevent_destroy` on stateful resources turns an accidental destroy into a plan error instead of data loss. The Terraform registry MCP, when configured, supplies current versions so pins are deliberate rather than guessed.

**Cluster provisioning lives here; anything that runs *inside* a cluster belongs to `komdosh-dev-infra-k8s`.**

@rules/terraform-style.md
@rules/terraform-state-safety.md
@rules/terraform-plan-review.md
@rules/yc-terraform.md
@rules/yc-security.md
@rules/yc-managed-services.md
@rules/yc-data-residency.md
