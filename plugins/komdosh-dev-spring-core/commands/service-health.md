---
description: Pre-production readiness audit of the whole service — docs, architecture, tests, migrations, coroutine safety, error handling, observability.
---

# /service-health

`code-reviewer` at `scope=service`. For reviewing a change instead, use `/review`.

1. `read-service-context`.
2. Invoke `code-reviewer` with `scope=service` and the full checklist.
3. Present findings grouped by category, severity-ordered, each with the command or agent that remediates it. **QA-artifact findings are WARNING at most** — tooling outputs, not production requirements.
4. State `READY` / `NOT READY (N blockers, M warnings)`, with the evidence for each category called clean.
5. Offer to work the blockers **one at a time, verifying after each**, and confirm before continuing to the next.
