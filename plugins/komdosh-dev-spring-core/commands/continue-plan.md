---
description: Resume an implementation plan one task at a time — execute, tick the checkbox, verify, and confirm before the next.
---

# /continue-plan

1. Find the active plan in `docs/plans/` (canonical) or `docs/specs/` (output of `/analyze-requirements`). Several → ask which. None → point to `/analyze-requirements`.
2. Read it; report `N of M tasks complete` and the last completed title.
3. Identify the next task with unchecked steps; name it and the files it touches.
4. **Ask before executing** — `y` proceed / `n` stop and summarise what remains / `s` skip.
5. Execute exactly the steps as written, using the agents and skills they name. **Do not improvise outside the task's scope.**
6. Tick each `- [ ]` → `- [x]` in the plan file as it completes.
7. `run-verification`. A failure is fixed before the task is marked complete.
8. Report, then ask before the next task.
