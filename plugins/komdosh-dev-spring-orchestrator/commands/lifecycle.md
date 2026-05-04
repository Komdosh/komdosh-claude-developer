# /lifecycle [status | next | orchestrate | audit] [args...]

Top-level workflow supervisor + advisor + orchestrator. Reports which development-lifecycle gates are met / pending / N/A on the current branch, recommends the highest-leverage next action, and (with confirmation) chains the work toward "ready to ship".

## Usage

```text
/lifecycle                          # default = status + next-action recommendation (Advise mode)
/lifecycle status                   # status only — no recommendation, no action
/lifecycle next                     # status + next-action recommendation (Advise mode)
/lifecycle orchestrate              # status + recommend + invoke (with confirmation per step, capped at 5)
/lifecycle audit <gate-number>      # explain the criteria + current evidence for one specific gate
```

## Steps

- [ ] **Step 1: Parse the subcommand**

| Arg | Mode |
|---|---|
| (none) or `next` | Advise |
| `status` | Status |
| `orchestrate` | Orchestrate |
| `audit <N>` | Audit (deep-dive on gate N) |

If unrecognised, default to Advise and surface the typo as a one-line note.

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 3: Invoke `lifecycle-supervisor`**

Pass the mode and any sub-args. The agent:

1. Runs the `lifecycle-status` skill (also detects which marketplace plugins are installed).
2. Prints the gate table.
3. Acts per the chosen mode:
   - **Status** → stops after the table.
   - **Advise** → adds a "Next" block recommending the highest-leverage gate to address, with the exact command/agent to invoke and a one-sentence rationale.
   - **Orchestrate** → loops through gates, confirming before each invocation and stopping on failure or after 5 actions.
   - **Audit** → re-runs the underlying skill for that gate, prints the full evidence, and recommends a specific action.

- [ ] **Step 4: Report**

Print the agent's full output verbatim — the table is dense and the user typically jumps to a specific gate row.

In Orchestrate mode, the agent prints a per-action confirmation prompt before each invocation. Forward those prompts to the user as-is; do not paraphrase.

- [ ] **Step 5: Suggest follow-ups**

If the agent reported a clean pipeline (0 PENDING, 0 UNKNOWN), suggest:

> "All gates met. To open a PR: run `/pr-summary` (gate 16). To deploy: that's outside the marketplace's scope — follow your team's deploy runbook."

If the agent stopped because a step failed, suggest the routing it printed (e.g. "verification failed → run `/test-fix` for the failing class, then `/lifecycle next`").

If the agent stopped because the 5-action cap was hit in orchestrate mode, suggest: "Re-run `/lifecycle orchestrate` to continue from the new state."

## Notes

- This command is read-most: `status`/`next`/`audit` modes never modify code. Only `orchestrate` invokes other agents/commands, and only after confirmation per step.
- Gate definitions and recommended actions live in [`agents/lifecycle-supervisor.md`](../agents/lifecycle-supervisor.md). The gate evaluation logic lives in [`skills/lifecycle-status/SKILL.md`](../skills/lifecycle-status/SKILL.md).
- Some gates (14 — QA artifacts, 11 — jOOQ freshness, 7 — migration registered) are N/A when their underlying capability is not in the project. The skill detects this and emits N/A automatically — no manual configuration needed.
