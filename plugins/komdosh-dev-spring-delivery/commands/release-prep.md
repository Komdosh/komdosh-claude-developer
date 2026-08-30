---
description: Run the full release-readiness pipeline for the detected track and open the release PR, stopping on any failed gate with its remediation.
argument-hint: "[version] [--track=service|library]"
---

# /release-prep

`read-service-context`, then `release-coordinator` with any version and `--track` override.

**Print the agent's report verbatim** — it is already structured; re-summarising loses the per-gate evidence.

Then:

- **PR opened** → review changelog, version, and playbook/ABI; merge; push the release tag with the exact command the agent printed; CI deploys or publishes.
- **Stopped at a gate** → the exact remediation, then re-run.
- **Track ambiguous** → re-run with `--track=service|library`, or add `kind:` to `service.yaml` to make it stick.
