# Environment Promotion

Environments (dev → staging → prod) exist to catch problems before they reach users. That guarantee only holds if what you tested is what you ship. The core rule: **promote the same artifact; change only configuration.**

## The same-artifact rule

- Build the deployable artifact (container image, Terraform module version, Helm chart version) **once**, tag it immutably, and promote *that exact tag/digest* through the environments.
- **Never rebuild between environments.** A rebuild for staging vs prod means prod runs code that was never tested. The image that passed staging is the image that goes to prod, by digest.
- Configuration is what differs per environment — endpoints, replica counts, resource sizes, feature flags, secret *references* (not values) — never the artifact.

## How configuration differs per environment

| Tool | Per-environment mechanism | Shared vs per-env |
|---|---|---|
| Kubernetes | Kustomize overlays (`base/` + `overlays/{dev,staging,prod}/`) or Helm values-per-env (`values-prod.yaml`) | Base = shape; overlay = env deltas only |
| Terraform | Separate state per env (workspaces or, preferably, directory-per-env) with `*.tfvars` per env | Modules shared; root config + tfvars per env |
| ArgoCD | ApplicationSet generators, or one Application per env pointing at the env overlay/path | One source pattern; targetRevision/path per env |

Overlays carry **only the deltas**. If an overlay restates the whole manifest, the base has failed its job and drift between envs becomes invisible.

## Promotion is a reviewable diff

Promoting a change from staging to prod is a git operation — bump an image tag in `overlays/prod`, change `targetRevision` for the prod Application, advance an ApplicationSet generator. Because it's a diff, it is reviewable, approvable, and revertible. Promotion that happens by a human running a command against prod is not promotion; it is an unreviewed change.

## Gates increase with blast radius

- **dev** — fast, auto-promote on green; low ceremony.
- **staging** — the honest rehearsal: same topology shape as prod, real integrations, the artifact that will ship. If staging doesn't resemble prod, it doesn't protect prod.
- **prod** — explicit human approval; change window awareness; a stated rollback; the smallest diff that achieves the goal. Never combine a routine promotion with an infrastructure change in the same prod apply.

## Prod-only changes are a smell

A resource, flag, or config that exists only in prod (never exercised in a lower env) is untested by definition. Where feasible, every prod construct has a lower-environment analog. Where it genuinely cannot (a prod-only DR region, a prod secret), call it out explicitly so reviewers know it bypassed the rehearsal.
