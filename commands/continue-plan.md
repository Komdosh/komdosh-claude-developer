# /continue-plan

Resume an implementation plan one sub-task at a time. Reads the plan file, finds the next unchecked task, executes it, marks it done, verifies, and asks before continuing.

## Steps

- [ ] **Step 1: Locate the active plan**

Search the conventional plan locations in order. Stop at the first non-empty result:

```bash
ls -t docs/plans/*.md docs/specs/*.md 2>/dev/null | head -5
```

The plugin's canonical plan location is `docs/plans/`; `docs/specs/` holds analysis output produced by `/analyze-requirements`.

If multiple plans exist, ask the user: "Which plan should I continue? (list the options)"
If only one exists, use it.
If none exist: "No plan found. Use `/analyze-requirements` to produce a spec, or write a plan in `docs/plans/`."

- [ ] **Step 2: Read the plan and find state**

Read the plan file. Find all `- [x]` (completed) and `- [ ]` (pending) checkboxes.
State: "N of M tasks complete. Last completed: <title>."

- [ ] **Step 3: Identify the next task**

Find the first task block where the task header is not yet fully checked (i.e., it has at least one `- [ ]` step that has not been completed by working through its sub-steps).

State: "Next task: **Task N — <title>**"
List the files it will create or modify.

- [ ] **Step 4: Confirm before executing**

Ask: "Proceed with Task N? (y to continue, n to stop, s to skip)"
- `y` → execute
- `n` → stop and summarize remaining tasks
- `s` → mark task as skipped and move to next

- [ ] **Step 5: Execute the task**

Follow every step in the task exactly. Use the agents and skills specified.
Do not improvise outside the task scope.

- [ ] **Step 6: Mark steps complete**

After each step completes successfully, update the plan file: change `- [ ]` to `- [x]` for that step.

- [ ] **Step 7: Run verification**

After all steps in the task are done, run `run-verification` skill.
If verification fails, fix the issue before marking the task complete.

- [ ] **Step 8: Ask to continue**

State: "Task N complete. Verification: [PASS/FAIL summary]."
Ask: "Continue to Task N+1 — <next title>? (y/n)"

Repeat from Step 3 until all tasks are done or the user says no.
