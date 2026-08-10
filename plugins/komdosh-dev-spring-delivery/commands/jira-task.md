# /jira-task [PROJ | PROJ-123]

Pull one Jira ticket from a project's "Todo" column, transition it forward, hand its description to `lifecycle-supervisor` as the captured requirement, then transition forward again on a clean gate map (or ask).

This command is **the only entry point**. Do not invoke `discover-jira-task` from any other command or agent.

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
| `PROJ` | Use `PROJ` as the project key; ignore the yaml. |
| `PROJ-123` (matches `^[A-Z][A-Z0-9_]+-\d+$`) | Skip the JQL fetch; pass the ticket key straight to the skill. |
| Anything else | Print usage and exit. |

- [ ] **Step 2: Run the `discover-jira-task` skill**

Pass the parsed argument. The skill probes for an Atlassian MCP (and exits with an install hint if none), resolves the project key, fetches the ticket, applies the **first forward transition** (Todo → typically "In Progress"), and returns a bundle:

```text
key · summary · description · priority · labels · components · parent_epic
browse_url · source_status · current_status · mcp_tool_prefix
```

`mcp_tool_prefix` names the Atlassian MCP namespace the skill resolved — reuse it for the second transition; do **not** re-probe.

If the skill exits for any reason (no MCP, empty queue, no transition available), surface its message and stop. Do not continue.

- [ ] **Step 3: Format the requirement memo**

Compose the memo that becomes the supervisor's gate-1 evidence, and print it so the user sees exactly what is being handed over:

```text
Working on <KEY>: <summary>

<description>

— Source: <browse_url> (priority: <priority>; labels: <labels>; components: <components>)
```

- [ ] **Step 4: Invoke `lifecycle-supervisor` in Orchestrate mode**

Hand over the memo with this instruction:

> "Treat the memo above as the captured requirement (gate 1 → MET). Run Orchestrate mode. Stop on the first failure or after 5 actions, per your normal safety cap."

Do not improvise gate evaluations here — the supervisor owns the gate map. Trust its report.

It returns on one of: a **clean exit** (0 PENDING + 0 UNKNOWN), a **step failure**, the **5-action cap**, or a **user stop**.

- [ ] **Step 5: Decide the second forward transition**

- **0 PENDING + 0 UNKNOWN** → apply it automatically. List the ticket's transitions via the Atlassian MCP, pick the first whose target `statusCategory` differs from the current one (or is the next `indeterminate` step), and apply. Typical result: "In Progress" → "In Review".
- **Anything else** — PENDING gates remain, the supervisor hit a blocker, the cap fired, or the user aborted → ask with `AskUserQuestion`:
  - **Move forward anyway** — for when the user wants review despite open gates.
  - **Leave in In Progress** — the recommended default when the supervisor stopped on a real blocker.
  - **Exit without further changes** — same, and skip the report enrichment.

Never skip this prompt when the gates aren't clean. A premature "In Review" is a lie told to the whole team.

- [ ] **Step 6: Apply the transition (if any)**

Use the same MCP namespace the skill used. If the call fails, print the error verbatim and leave the ticket where it is — **do not retry blindly**:

- **401/403** → print the auth error, exit.
- **No forward transition available** → "board may be misconfigured — manual transition required," exit.
- **Supervisor returned no gate snapshot** → treat as the "anything else" branch in step 5 and ask.

- [ ] **Step 7: Final report**

```text
Jira task session summary
  Ticket:    <KEY>  <browse_url>
  Started:   <source_status>
  Now in:    <current status after this session>
  Gates:     <met>/<total>  (PENDING: <list>, UNKNOWN: <list>)
  Actions:   <count taken by the supervisor>
  Next:      <one line>
```

The `Next` line:

- clean + transitioned → `open a PR — run /pr-summary, then /lifecycle next.`
- gates remain + transitioned → `address the remaining PENDING gates before review approval — see the supervisor's report above.`
- left in In Progress → `resume with /jira-task <KEY> when ready.`

## Notes

- **Explicit trigger only.** `/lifecycle`, `/recommend`, and other commands must not invoke this flow.
- **Atlassian MCP required.** No manual-paste fallback.
- **Forward-only walk.** Status names are never hardcoded — the project's own workflow is the authority.
- **One ticket per invocation**, no batching. This flow only *transitions* a ticket: it never comments, closes, or creates sub-tasks.
- **Aborted work stays in "In Progress."** Re-run with the explicit `PROJ-123` form to resume.
