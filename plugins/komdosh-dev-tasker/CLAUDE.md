# CLAUDE.md — komdosh-dev-tasker

This plugin bridges Jira tickets to the marketplace's `lifecycle-supervisor`. It pulls one ticket from a project's "Todo" column, hands the description to the supervisor as the captured requirement, and transitions the ticket forward as work progresses.

## When to use

The plugin is **explicit-trigger only**. It activates when the user runs `/jira-task` with (optionally) a project key or ticket id. Never fires on natural-language ambiguity — the agent and skill must not be invoked by other commands.

## What it adds

| Item | Purpose |
|---|---|
| Command [`/jira-task`](commands/jira-task.md) | `/jira-task` (uses `.claude/jira.yaml`) · `/jira-task PROJ` (override project key) · `/jira-task PROJ-123` (specific ticket). Single user-facing entry point. |
| Agent [`jira-task-coordinator`](agents/jira-task-coordinator.md) | Opus. Receives the ticket bundle from the skill, formats a one-line requirement memo, invokes `lifecycle-supervisor` in Orchestrate mode, then decides whether to apply the second forward transition (Todo → In Progress already done by the skill; this step is In Progress → In Review). Auto-transitions on a clean gate map; otherwise asks the user. |
| Skill [`discover-jira-task`](skills/discover-jira-task/SKILL.md) | Read-mostly. Detects the Atlassian MCP, resolves the project key, fetches one ticket, lists transitions, picks the first forward transition, applies it, returns the ticket bundle. Refuses to run if the MCP is not detected. |

## Flow at a glance

```
/jira-task PROJ
   │
   ├─[skill discover-jira-task]
   │    1. probe MCP                      → exit if missing (with install hint)
   │    2. resolve project key            → arg | .claude/jira.yaml | AskUserQuestion
   │    3. fetch ticket                   → JQL "statusCategory = To Do" or by key
   │    4. list transitions               → pick first forward (cross-category)
   │    5. apply transition               → ticket now in "In Progress"
   │    6. return ticket bundle
   │
   ├─[agent jira-task-coordinator]
   │    1. format requirement memo        → "Working on <KEY>: <summary>" + description
   │    2. invoke lifecycle-supervisor    → orchestrate mode
   │    3. wait for supervisor to return
   │    4. re-run lifecycle-status
   │       ├─ 0 PENDING                   → auto-transition forward (now "In Review")
   │       └─ otherwise                   → AskUserQuestion (move | leave | exit)
   │
   └─ final report (key, gates closed, current Jira status, next step)
```

## Forward-only column walk

The plugin does **not** hardcode status names like `"To Do"`, `"In Progress"`, `"In Review"` — Jira workflows differ across projects. Instead, the skill calls Jira's transitions API for the issue and applies the first transition whose target's `statusCategory` differs from the source's. The first walk takes a `new`-category status (Todo) into `indeterminate` (whatever the project calls it). The second walk, performed by the coordinator after the supervisor finishes, takes that `indeterminate` status into the next `indeterminate` step (typically "In Review") or, if the workflow has only one indeterminate step, into a `done`-category status — which is why we **default to asking the user** unless gates are clean.

## Failure handling

- **MCP missing** → refuse fast with an install hint. No fallback to manual paste.
- **Ticket queue empty** → exit cleanly, suggest the user check their Jira filter.
- **Supervisor errors mid-flight** → leave the ticket in "In Progress." Print the key + browse URL so the user can resume in a new session.
- **No forward transition available** → "board misconfigured" message, exit. The user must transition manually.

## Config — `.claude/jira.yaml`

Optional, project-scoped:

```yaml
project: PROJ
```

That's the entire schema. The plugin trusts Jira's workflow for everything else.

## Dependencies

- **Required**: [`komdosh-dev-spring-core`](../komdosh-dev-spring-core/) — transitive (the supervisor's downstream agents live here).
- **Required**: [`komdosh-dev-spring-orchestrator`](../komdosh-dev-spring-orchestrator/) — provides `lifecycle-supervisor`.
- **Required at runtime**: an Atlassian MCP server providing Jira issue search, read, transition list, and transition apply. The plugin probes by tool prefix (`mcp__*atlassian*` or `mcp__*jira*`); the first match wins. If none is detected, the plugin refuses to run.

## Why a separate plugin

Jira-driven entry is opt-in. Many teams plan in GitHub Issues, Linear, or plain-text docs and would not want a slash command that requires an Atlassian MCP. Keeping this plugin separate lets those teams ignore it entirely while preserving zero-Jira install paths for the rest of the marketplace.
