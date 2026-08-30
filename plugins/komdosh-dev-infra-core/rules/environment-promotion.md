# Environment Promotion

Environments only protect users if what you tested is what you ship: **promote the same artifact, change only configuration.**

- Build once, tag immutably, promote **that exact digest** through every environment.
- **Never rebuild between environments** — a rebuild for prod means prod runs code staging never saw.
- What differs per environment is configuration: endpoints, replica counts, resource sizes, flags, and secret **references** (never values).

## Mechanism per tool

Kustomize `base/` + `overlays/<env>/`, or Helm values-per-env · Terraform state per environment (directory-per-env over workspaces) with per-env tfvars, modules shared · ArgoCD ApplicationSet generators or one Application per env.

**Overlays carry only the deltas.** An overlay that restates the whole manifest means the base has failed its job, and differences between environments become invisible.

## Promotion is a reviewable diff

Bumping a tag in `overlays/prod`, moving a prod `targetRevision`, advancing a generator — all diffs, so all reviewable, approvable, and revertible. **A human running a command against prod is not promotion; it is an unreviewed change.**

## Gates scale with blast radius

**dev** auto-promotes on green. **staging** is the honest rehearsal — prod's topology shape, real integrations, the artifact that will ship; if it doesn't resemble prod it doesn't protect prod. **prod** takes explicit approval, a stated rollback, and the smallest diff that achieves the goal. **Never combine a routine promotion with an infrastructure change in one prod apply.**

## Prod-only constructs are a smell

Anything that exists only in prod is untested by definition. Where a lower-environment analog genuinely isn't possible (a DR region, a prod secret), say so explicitly so reviewers know it bypassed the rehearsal.
