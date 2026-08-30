# Infrastructure Review

Same bar as any code review — **concrete, grounded findings ordered by severity, no filler, no speculation** — with infra-specific dimensions and a higher cost of a miss.

**The rendered desired state is the truth**: the `.tf`/manifests as written and the `plan`/`diff` they produce. Comments and PR text are context; where they disagree with the code, the code wins and the disagreement is itself a finding.

## The six dimensions, in order of attention

1. **Correctness** — a wrong CIDR, transposed ports, a probe on the wrong path, a selector matching nothing, `for_each` over the wrong set, **an overlay that doesn't actually override the base**.
2. **Blast radius** — what this reaches if wrong. Shared network, IAM, a base overlay, or an app-of-apps parent reaches far.
3. **Reversibility** — is the rollback one sentence? **Anything that replaces or destroys a stateful resource is a blocker until a backup and sign-off exist.**
4. **Security** — plaintext secrets, `0.0.0.0/0`, over-broad IAM, privileged containers, disabled encryption, public buckets. Least privilege is the default; a deviation needs a justification.
5. **Drift and GitOps hygiene** — mutable tags or revisions, unpinned providers/charts/modules, partial-GitOps carve-outs.
6. **Cost** — oversized or always-on resources, missing autoscaling, unbounded retention, orphans, duplicated NAT/load balancers. Rarely blocking; still worth naming.

## Severity

**BLOCKER** — data loss, security exposure, or an outage is a plausible outcome of merging as-is. **WARNING** — a real defect that bites later, not immediately. **INFO** — a smaller improvement.

## Discipline

- Cite `file:line` and the **concrete impact** — "if this applies, the `orders` cluster is replaced and its data is lost" — never a bare category.
- **Read the rendered plan when one is available.** A silent replace or an unexpected delete is invisible in source and obvious in the plan.
- **Never call a change clean without a second pass** looking for what the first missed. A clean verdict states its evidence: "3 files, all additive, no replace/destroy in the plan, no new exposure."
- Report only what the diff grounds. No speculation about unstarted work.
