# /jira-task [PROJ | PROJ-123]

Pull one Jira ticket from a project's "Todo" column, transition it forward, hand the description to `lifecycle-supervisor` as the captured requirement, then transition forward again on supervisor completion (or ask the user).

This command is **the only way** to invoke this plugin. Do not call `jira-task-coordinator` or `discover-jira-task` from any other command or agent.

## Usage

```text
/jira-task                  # uses .claude/jira.yaml; asks if no config
/jira-task PROJ             # override project key; first ticket from PROJ's Todo column
/jira-task PROJ-123         # work on this exact ticket regardless of column
```

## Steps

- [ ] **Step 1: Parse the argument**

| Arg form | Behaviour |
|---|---|
| (none) | Read `project:` from `.claude/jira.yaml`. If absent, ask via `AskUserQuestion`. |
| `PROJ` | Use `PROJ` as the project key; ignore yaml. |
| `PROJ-123` (matches `^[A-Z][A-Z0-9_]+-\d+$`) | Skip the JQL fetch; pass the ticket key directly to the skill. |
| Anything else | Print usage and exit. |

- [ ] **Step 2: Run the `discover-jira-task` skill**

Pass the parsed argument (project key, ticket key, or "ask"). The skill:

1. Probes for an Atlassian MCP (tool prefix scan). If missing, prints the install hint and exits — **do NOT continue to step 3.**
2. Resolves the project key.
3. Fetches the ticket (JQL for project key, direct fetch for ticket key).
4. Lists transitions on the ticket and applies the first forward transition (Todo → next status, typically "In Progress").
5. Returns the ticket bundle.

If the skill exits (MCP missing, queue empty, transition unavailable), surface the message and stop. Do NOT proceed to step 3.

- [ ] **Step 3: Invoke `jira-task-coordinator`**

Pass the ticket bundle from step 2. The agent:

1. Formats a one-line "Requirement captured" memo from the ticket summary + description.
2. Invokes `lifecycle-supervisor` in Orchestrate mode with the memo as the requirement.
3. Waits for the supervisor to return (clean exit, blocker, or 5-action cap).
4. Re-runs `lifecycle-status`. If `0 PENDING + 0 UNKNOWN`, applies the second forward transition (typically "In Review") automatically. Otherwise asks the user.

- [ ] **Step 4: Final report**

Print the agent's full output verbatim. End with:

```text
Jira task session summary
  Ticket:    <KEY>  <browse url>
  Started:   <Todo column status name>
  Now in:    <current status name>
  Gates:     <met>/<total>  (PENDING: <list>)
  Next:      <one-line — usually "open PR" or "resume /jira-task <KEY>">
```

## Notes

- **Explicit trigger only.** This command is the sole entry point. The agent and skill must not be invoked by `/lifecycle`, `/recommend`, or any other command.
- **Atlassian MCP required.** The skill refuses to run without it; there is no manual-paste fallback.
- **Forward-only walk.** Status names are not hardcoded — the plugin trusts the project's workflow.
- **One ticket per invocation.** No batching. Re-run for the next ticket.
- **Aborted work stays in "In Progress."** Re-run with the explicit `PROJ-123` form to resume.
