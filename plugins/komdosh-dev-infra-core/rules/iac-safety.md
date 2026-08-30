# IaC Safety — 12 Forbidden Patterns

A bad `apply` deletes a database; a bad `sync` takes down a cluster. `infra-safety-scan` greps these.

| # | Pattern | Correct alternative |
|---|---|---|
| 1 | Plaintext secret in a committed file | Reference a secret store — `rules/secrets-hygiene.md`. **The secret is in history forever; rotation is the only remedy** |
| 2 | Mutable image tag (`:latest`, `:main`, none) on a deployed workload | An immutable digest or a unique tag — otherwise the running version is unknowable and rollback impossible |
| 3 | `apply -auto-approve` on an unreviewed plan | `plan` → review → apply the **saved** plan. Auto-approve only behind a reviewed CI gate |
| 4 | `kubectl apply`/`edit` against a GitOps-managed cluster | Change git and let the controller sync — `rules/gitops-principles.md` |
| 5 | `0.0.0.0/0` on a non-public port | Scope the CIDR. Public only for genuinely public ports |
| 6 | Workload with no resource requests/limits | One pod's leak evicts its neighbours and the scheduler can't place it |
| 7 | Local Terraform state in a shared repo | Remote backend with locking and encryption |
| 8 | `for_each`/`count` keyed by list index or a reordering value | **Key by a stable identifier** — reindexing destroys and recreates unrelated resources on the next plan |
| 9 | Destroy or replace of a stateful resource without a backup and sign-off | Snapshot first; `prevent_destroy` on stateful resources. **`forces replacement` is easy to miss in a plan** |
| 10 | Manual undocumented change to a running resource | Every change goes through code and review; import pre-existing resources into state |
| 11 | One giant blast radius — a single root module or Application for everything | Split by lifecycle and blast radius; promote independently |
| 12 | Floating provider, module, chart, or base-image versions | Pin `version`, `?ref=`, chart `version`, image digest |

## The apply/sync contract

**Render** the desired state (`terraform plan`, `helm template`, `kustomize build`, `argocd app diff`) and read it → **review** what is created, updated, **replaced**, or **destroyed**, and which of it is stateful → **apply the exact reviewed artifact**, never something newer.

A plan that only adds is low-risk. Any destroy or replace is a stop-and-think.

## Reversibility first

App or config → revert and resync, or redeploy the previous immutable tag. Additive schema or infra → safe forward. Destructive or replacing → **no cheap inverse; needs a backup and an explicit logged decision, and is never bundled with unrelated changes.**

**When you cannot state the rollback in one sentence, the change is not ready.**
