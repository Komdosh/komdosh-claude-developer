---
description: Pull one Jira ticket from the project's Todo column via the Atlassian MCP, walk its workflow forward, and hand the description to the lifecycle supervisor.
argument-hint: "[PROJ | PROJ-123]"
---

# /jira-task

**Requires an Atlassian MCP server — refuse without one.** There is no manual-paste fallback: a pasted description with no ticket to transition is just `/analyze-requirements`.

1. Resolve the project key: the argument → `.claude/jira.yaml`'s `project:` → ask.
2. `discover-jira-task` fetches one ticket from the Todo column (or the named ticket) and applies the **first forward workflow transition**.
   **Never hardcode a status name.** Teams rename columns; walk the transitions the API reports.
3. Hand the description to `lifecycle-supervisor` as the captured requirement (gate 1).
4. On a clean gate map at the end of the work, apply the next forward transition.

Report the ticket key, summary, the transition applied, and the supervisor's recommended next action.
