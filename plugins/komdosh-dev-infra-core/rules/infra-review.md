# Infrastructure Review

How to review an infrastructure change. The bar is the same as any code review — **concrete, code-grounded findings ordered by severity, no filler, no speculation** — but the dimensions are infra-specific and the cost of a miss is higher.

## Source of truth

The rendered desired state is the truth: the `.tf`/manifests/values as written, and the `plan`/`diff` they produce. Comments, PR descriptions, and commit messages are context, not evidence. When they disagree with the code, the code wins and the disagreement is a finding.

## The six dimensions

Review every infra diff across these, in this order of attention:

1. **Correctness** — does it do what it claims? Wrong CIDR, transposed ports, a probe pointing at the wrong path, a selector that matches nothing, a `for_each` over the wrong set, an overlay that doesn't actually override the base.
2. **Blast radius** — what does the change touch, and what could it take down if wrong? A change to shared network / IAM / a base overlay / an app-of-apps parent reaches far. Prefer changes whose failure is contained to one service.
3. **Reversibility** — is there a one-sentence rollback? Flag anything that **replaces or destroys** a stateful resource, or that has no cheap inverse. `forces replacement` on a database is a blocker until a backup + sign-off exist.
4. **Security** — secrets in plaintext (see `rules/secrets-hygiene.md`), `0.0.0.0/0` exposure, over-broad IAM (`*` actions, admin/editor roles), privileged containers, disabled encryption, public buckets. Least privilege is the default; deviations must be justified.
5. **Drift & GitOps hygiene** — does the change keep git as the source of truth, or does it invite out-of-band edits? Mutable tags/revisions, unpinned providers/charts/modules, and partial-GitOps carve-outs are findings (see `rules/gitops-principles.md`).
6. **Cost & efficiency** — oversized instances, always-on resources that could scale to zero, missing autoscaling, unbounded retention, orphaned resources, duplicated NAT/load-balancers. Not every review blocks on cost, but call out the obvious waste.

## Severity

- **BLOCKER** — data loss, security exposure, or an outage is a plausible outcome of merging as-is. (Unguarded destroy of a stateful resource; a committed secret; world-open admin port; broken prod source-of-truth.)
- **WARNING** — a real defect or a violated convention that will bite later but isn't an immediate outage. (Unpinned provider; missing resource limits; overlay drift; over-broad-but-not-admin IAM.)
- **INFO** — a smaller improvement, style, or a note worth the author's attention. (Naming, tagging, a cheaper equivalent resource.)

## Discipline

- Cite `file:line` and the **concrete impact** ("if this applies, the `orders` RDS is replaced and its data is lost"), not a category label.
- Read the rendered plan/diff when one is available — many defects (a silent replace, an unexpected delete) are invisible in the source but obvious in the plan.
- **Re-scan before a clean verdict.** Never call a change clean without a second pass looking for what the first missed. A clean verdict states its evidence: "3 files, all additive, no replace/destroy in the plan, no new external exposure."
- Report only what is grounded in the diff. No speculation about unstarted work, no inventing risks the code doesn't create.
