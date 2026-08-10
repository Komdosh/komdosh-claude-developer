# /service-health

Pre-production readiness audit of the whole service, via `code-reviewer` at `scope=service`.

For reviewing a change rather than the service, use `/review` (the same agent at `scope=diff`).

## Steps

- [ ] **Step 1: Load service context**

Run the `read-service-context` skill.

- [ ] **Step 2: Invoke `code-reviewer`**

Pass `scope=service` and ask for the full checklist: Documentation, QA artifacts, Architecture, Tests, Migrations, Coroutine Safety, Error Handling, Observability.

- [ ] **Step 3: Present findings**

Grouped by category, ordered by severity within each:

```
BLOCKER [CATEGORY]: <description>
→ Fix with: <command or agent>

WARNING [CATEGORY]: <description>
→ Fix with: <command or agent>
```

QA-artifact findings are WARNING at most — they are tooling outputs, not production requirements.

- [ ] **Step 4: Conclude**

State: "Service readiness: **READY** / **NOT READY** (N blockers, M warnings)", with the agent's stated evidence for the categories it called clean.

- [ ] **Step 5: Offer to fix the blockers**

If blockers exist: "Want me to work through the blockers? I'll take them one at a time, verify after each, and check with you before continuing."

If the user agrees: remediate the first BLOCKER, run the `run-verification` skill, confirm, then move to the next.
