---
description: Review the current diff with the code-reviewer agent across correctness, contract hygiene, observability, abstraction quality, and future-proofing.
argument-hint: "[--focus dim1,dim2]"
---

# /review

`code-reviewer` at `scope=diff`. For a whole-service readiness audit instead, use `/service-health` (same agent, `scope=service`).

Dimensions for `--focus`: `correctness`, `contract-hygiene`, `observability`, `abstraction-quality`, `future-proofing`.

1. Confirm the base branch rather than assuming, then `git diff <base>...HEAD` — falling back to `git diff --cached`. Both empty → say so and stop.
2. Invoke `code-reviewer` with `scope=diff`, the base, and any `--focus`.
3. Run `run-verification` on the affected modules.
4. Present findings severity-ordered, then the verification results.
5. Close with the agent's recommendation and **its stated evidence for anything it called clean**.
