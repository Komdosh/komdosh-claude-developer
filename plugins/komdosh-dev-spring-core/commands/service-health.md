# /service-health

Run a pre-production readiness audit on the service. Invokes `service-readiness-auditor` and presents findings with remediation guidance.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` skill.

- [ ] **Step 2: Invoke service-readiness-auditor**

Pass the service context and ask for a full audit across all categories: Documentation, Architecture, Tests, Migrations, Coroutine Safety, Error Handling, Observability.

- [ ] **Step 3: Present findings**

Group findings by category. Within each category, order by severity: BLOCKERs first, then WARNINGs, then INFOs.

For each BLOCKER:
```
BLOCKER [CATEGORY]: <description>
→ Fix with: <agent-name>
```

For each WARNING:
```
WARNING [CATEGORY]: <description>
→ Fix with: <agent-name>
```

- [ ] **Step 4: Conclude**

State: "Service readiness: **READY** / **NOT READY** (N blockers, M warnings)"

- [ ] **Step 5: Offer to fix blockers**

If blockers exist: "Want me to work through the blockers? I'll tackle them one at a time, verify after each, and ask before continuing."

If user says yes: invoke the remediation agent for the first BLOCKER, run `run-verification` skill, then confirm before moving to the next.
