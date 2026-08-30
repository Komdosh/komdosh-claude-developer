---
description: Report which development-lifecycle gates are met, pending, or N/A on this branch, recommend the next action, and optionally chain the work toward ready-to-ship.
argument-hint: "[status|next|orchestrate|audit <gate>]"
---

# /lifecycle

| Arg | Mode |
|---|---|
| none, `next` | Advise — status + recommendation |
| `status` | Status — table only |
| `orchestrate` | Invoke, confirming each step, capped at 5 |
| `audit <N>` | Deep-dive one gate: full evidence + a specific action |

Unrecognised arg → Advise, with a one-line note about the typo.

`read-service-context`, then `lifecycle-supervisor` with the mode. It runs `lifecycle-status` (which also discovers the installed plugins), prints the gate table, and acts per mode.

**Print the agent's output verbatim.** The table is dense and the user typically jumps to one row — summarising it removes exactly what they came for. In orchestrate mode, forward the per-action confirmation prompts as-is.

Follow-ups: a clean pipeline → `/pr-summary`, and note that deploying is outside the marketplace's scope. A failed step → the routing the agent printed. The 5-action cap → re-run to continue from the new state.

`status`, `next`, and `audit` never modify anything; only `orchestrate` invokes, and only after confirmation.
