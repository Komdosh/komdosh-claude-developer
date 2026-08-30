---
description: Ask the marketplace which plugin and entry point best fits a task, with rationale, exact invocation, and an install hint if it is missing.
argument-hint: "[task description]"
---

# /recommend

Args are the task signal verbatim. With none, scan the last few turns for the most recent unaddressed request; if nothing is actionable, ask for one line.

Invoke `recommend-plugin` and **print its block as-is** — it is self-contained.

Then one line of next action: the invocation if the plugin is installed, the install command if not, or the skill's own redirect on a no-match. **Never auto-invoke** — the user decides.

For "what's next on this branch" use `/lifecycle`; for "have we decided this before" use `/reveal`.

The catalog is read at runtime, so a newly-shipped plugin is picked up with no edit here.
