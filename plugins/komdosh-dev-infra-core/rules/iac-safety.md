# IaC Safety — Forbidden Patterns

Infrastructure code changes production reality. A bad `apply` deletes a database; a bad `sync` takes down a cluster. These patterns are forbidden in any infrastructure code you generate or approve. They are the infra analog of a null-pointer bug: cheap to prevent, expensive to survive.

| # | Pattern | Why it breaks | Correct alternative |
|---|---|---|---|
| 1 | Plaintext secret in a committed file (`.tf`, `.tfvars`, k8s manifest, values.yaml, CI YAML) | Secret is in git history forever; rotating it is the only remedy | Reference a secret store — see `rules/secrets-hygiene.md` |
| 2 | Mutable image tag (`:latest`, `:main`, no tag) in a deployed workload | The running version is unknowable and changes under you; rollbacks are impossible | Immutable digest (`@sha256:…`) or a unique semver/commit tag |
| 3 | `terraform apply -auto-approve` in interactive or unreviewed context | Applies an unseen plan; the diff is where destroys hide | Always `plan` → review → `apply` the saved plan; auto-approve only behind a reviewed CI gate |
| 4 | `kubectl apply`/`kubectl edit` against a GitOps-managed cluster | Creates drift the controller will fight or silently revert; the change isn't in git | Change git, let the controller sync — see `rules/gitops-principles.md` |
| 5 | Ingress/security-group open to `0.0.0.0/0` on a non-public port | Exposes internal services (DBs, admin, metrics) to the internet | Scope CIDRs to known ranges; public only for genuine public ports (80/443) |
| 6 | Workload with no resource requests/limits | One pod's leak evicts its neighbors; the scheduler can't place it | Always set requests and limits — see the kubernetes plugin's `rules/k8s-resources.md` |
| 7 | Local Terraform state in a team/shared repo | Concurrent applies corrupt state; no locking; state lives on one laptop | Remote backend with locking and encryption — see the terraform plugin's `rules/terraform-state-safety.md` |
| 8 | `for_each`/`count` keyed by a list index or a value that reorders | Reindexing destroys and recreates unrelated resources on the next plan | Key by a stable identifier (name/id), not position |
| 9 | Destroy or replace of a stateful resource (DB, disk, bucket) without a backup + explicit sign-off | Irreversible data loss; `forces replacement` is easy to miss in a plan | Snapshot first; `prevent_destroy` on stateful resources; make the replacement intentional |
| 10 | Manual, undocumented change to a running resource ("click-ops") | Divergence from code; the next `apply`/`sync` reverts or conflicts with it | Every change goes through code and review; import pre-existing resources into state |
| 11 | One giant blast radius (one root module / one Application for everything) | A single mistake can take down the whole estate; slow, risky plans | Split by lifecycle and blast radius (network / data / compute / app), promote independently |
| 12 | Pinning nothing — floating provider, module, chart, or base-image versions | Unrelated PRs pull in breaking upstream changes; builds aren't reproducible | Pin provider `version`, module `?ref=`, chart `version`, base image digest |

## The apply/sync contract

Every change to real infrastructure follows the same three-step contract, regardless of tool:

1. **Render the desired state** — `terraform plan`, `helm template`, `kustomize build`, `argocd app diff`. Read it.
2. **Review the diff for blast radius** — what is created, updated, **replaced**, or **destroyed**; what is stateful; what is irreversible. A plan that only adds is low-risk; any destroy/replace is a stop-and-think.
3. **Apply the exact reviewed artifact** — the saved plan, the pinned revision. Never apply something newer than what was reviewed.

## Reversibility first

Before any change, know the way back. Prefer changes that are reversible by construction:

- **App/config**: rollback = git revert + resync, or redeploy the previous immutable tag.
- **Additive schema/infra**: safe forward; the inverse is a drop (guarded).
- **Destructive/replacing**: has no cheap inverse — requires a backup and an explicit, logged decision. Never bundle a destroy with unrelated changes.

When you cannot state the rollback in one sentence, the change is not ready.
