---
name: discover-jira-task
user-invocable: false
description: Detect an Atlassian MCP server, resolve a Jira project key (arg → .claude/jira.yaml → AskUserQuestion), fetch one ticket from the project's Todo column (or by ticket key), apply the first forward workflow transition (typically Todo → In Progress), and return a structured ticket bundle. Refuses to run if no Atlassian MCP is detected. Read-mostly — the only side effect is the single forward transition. Used exclusively by the /jira-task command.
---

# Discover Jira Task

## When to Use

Called by the `/jira-task` command, which orchestrates the rest of the flow inline. Not used by any other command, agent, or skill.

## Output

A structured ticket bundle the coordinator agent consumes:

```text
key:             <PROJ-123>
summary:         <one-line title>
description:     <full description body, markdown preserved>
priority:        <Lowest|Low|Medium|High|Highest|null>
labels:          <comma-separated, may be empty>
components:      <comma-separated, may be empty>
parent_epic:     <KEY or "none">
browse_url:      <full https URL>
source_status:   <name of the column the ticket was in before this skill ran>
current_status:  <name of the column the ticket is in now (after the forward transition)>
mcp_tool_prefix: <e.g., mcp__plugin_engineering_atlassian — used by the coordinator>
```

If any step fails, do not return a bundle — print the error and exit.

## Steps

- [ ] **Step 1: Probe for an Atlassian MCP server**

Inspect the available tool list. Match any of:

- `mcp__*atlassian*__*`
- `mcp__*jira*__*` (some MCP servers expose Jira-specific endpoints under a separate namespace)

Take the **first** matching namespace prefix. Record it as `mcp_tool_prefix`. Within that namespace, expect tools that cover (names vary by vendor; do not hardcode):

- search Jira issues by JQL
- read a single Jira issue by key
- list available transitions on an issue
- apply a transition to an issue

If no namespace matches, exit with:

> "Atlassian MCP not detected. This plugin requires an Atlassian MCP server providing Jira issue search, read, and transition endpoints. Install one and re-run `/jira-task`. See https://www.atlassian.com/platform/mcp-server for the official option."

Do **not** fall back to manual paste. The plugin is opt-in for Jira-driven flows by design.

- [ ] **Step 2: Parse the input from the command**

The `/jira-task` command passes one of three forms:

| Form | Behaviour |
|---|---|
| `PROJ-123` (matches `^[A-Z][A-Z0-9_]+-\d+$`) | Treat as a direct ticket key. Skip steps 3–4; jump to step 5 (read ticket). |
| `PROJ` (matches `^[A-Z][A-Z0-9_]+$`) | Use as the project key. Continue. |
| `ask` | No project key from the command. Continue to step 3 with project = unknown. |

- [ ] **Step 3: Resolve the project key**

If step 2 already produced a project key, skip this step.

Otherwise, look for `.claude/jira.yaml` at the repo root:

```yaml
project: PROJ
```

If present and `project` is set, use that.

If absent or empty, use `AskUserQuestion`:

> "Which Jira project should I pull a ticket from? (e.g., PROJ)"

Reject anything that does not match `^[A-Z][A-Z0-9_]+$` — print the format hint and re-ask once. After two failed attempts, exit cleanly.

- [ ] **Step 4: Fetch the ticket via JQL**

Skip if step 2 produced a direct ticket key.

Use the MCP's JQL search tool with:

```text
project = <KEY> AND statusCategory = "To Do" ORDER BY priority DESC, created ASC
```

Limit the result to 1.

If the result is empty, exit with:

> "No tickets in `<KEY>` are in the 'To Do' status category. Add one to the queue or pass an explicit ticket id: `/jira-task <KEY>-<n>`."

If the result has one hit, record the ticket key and continue.

- [ ] **Step 5: Read the ticket**

Use the MCP's "read issue by key" tool. Capture: `summary`, `description`, `priority`, `labels`, `components`, `parent epic key`, `browse URL`, current `status name` (this is the `source_status` field of the bundle).

If the ticket is **not** in a `statusCategory = "To Do"` status (this can happen with the `PROJ-123` direct form), print a warning to the user but **do not exit** — the user explicitly asked for that ticket. Continue to step 6.

- [ ] **Step 6: List transitions**

Use the MCP's "get transitions for issue" tool on the ticket. Each transition has at minimum: id, name, target status name, target status category (`new` | `indeterminate` | `done`).

- [ ] **Step 7: Pick the first forward transition**

A transition is **forward** if either:

1. Its target status's category differs from the source status's category (most common from `new` → `indeterminate`), OR
2. Both source and target are in the same category, but the target's `statusCategory` ranking is the same and Jira's transition list places this transition first (reflecting board order).

Sort candidates by transition id ascending and pick the first. If none of the available transitions is forward, exit with:

> "Ticket `<KEY>` has no forward transition from `<source_status>`. The board may be misconfigured, or the ticket is in a terminal status. Move it manually in Jira and re-run."

- [ ] **Step 8: Apply the forward transition**

Use the MCP's "transition issue" tool with the chosen transition id. After the call returns, re-read the ticket's status name to populate `current_status`. If the transition fails (auth, permission, API error), print the error verbatim and exit — leaving the ticket in `source_status`. Do not retry.

- [ ] **Step 9: Return the bundle**

Emit the structured bundle (see "Output" above). The `/jira-task` command consumes it directly.

## Failure modes

| Cause | Behaviour |
|---|---|
| No Atlassian MCP detected | Exit with install hint (step 1). |
| Project key cannot be resolved | Exit after two failed `AskUserQuestion` attempts (step 3). |
| JQL search returns empty | Exit cleanly with "queue is empty" message (step 4). |
| Direct-key ticket not in Todo | Warn but continue (step 5). |
| No forward transition available | Exit with "board misconfigured" message (step 7). |
| Transition API call fails | Exit with the API error verbatim; ticket remains in source status (step 8). |

## Limits

- One ticket per invocation. No batching.
- Read + one transition. Never edits ticket fields, never adds comments, never closes.
- Tool-name agnostic. The skill works against any Atlassian MCP that exposes the four required capabilities (search, read, list transitions, apply transition).
- First MCP namespace wins. If the user has multiple Atlassian MCP servers configured (work + personal), the skill uses the first one it finds. Document this limit; richer selection is a follow-up.
