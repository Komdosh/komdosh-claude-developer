# /recommend [task description]

Ask the marketplace which plugin + agent/command/skill best fits a task. Wraps the `recommend-plugin` skill with a user-facing entry point.

## Usage

```text
/recommend                                       # use the most recent task signal in conversation
/recommend add a Kafka consumer for orders       # explicit task description
/recommend "I want to find vendor leaks"         # quoted form (recommended for multi-word tasks)
```

## Steps

- [ ] **Step 1: Resolve the task signal**

If args are present, treat them as the task signal verbatim. Strip surrounding quotes if any.

If args are empty, scan the last 3–5 turns of the conversation for the most recent unaddressed user request. If nothing actionable is found, ask the user to restate the task in one line.

- [ ] **Step 2: Invoke the `recommend-plugin` skill**

Pass the task signal as the focus input. The skill:

1. Reads the marketplace catalog (from `marketplace.json` if locatable, else from installed `plugin.json` files).
2. Detects which marketplace plugins are installed locally.
3. Matches the task signal against plugin descriptions + keywords using the disambiguation rules.
4. Emits a primary recommendation + up to two alternates with rationale, exact invocation, and an install hint if the plugin is missing.

- [ ] **Step 3: Print the recommendation verbatim**

The skill returns a self-contained markdown block. Print it as-is — do not summarise or restructure.

- [ ] **Step 4: Offer the obvious next action**

If the recommendation's primary plugin is **installed**: append one line — `Run \`<invocation>\` to proceed.` Don't auto-invoke; the user decides.

If the recommendation's primary plugin is **not installed**: append the install command the skill emitted, plus — `After install, re-run \`/recommend\` (or invoke the recommended entry point directly).`

If the skill emits **no match**: forward its suggestion (usually `/adr-new` or "out of marketplace scope") without embellishment.

## Notes

- This command is **read-only**. It never invokes the recommendation; it only surfaces it.
- For "what's next on this branch?" use `/lifecycle` instead — that walks the 16-gate pipeline. `/recommend` is for a single, explicit task.
- For "have we decided this before?" route to `/reveal` (revealer plugin) — `/recommend` will already redirect there if the task signal looks like a knowledge query, but a direct `/reveal` is shorter.
- The skill reads the catalog at runtime from `~/.claude/plugins/**/marketplace.json` and per-plugin `plugin.json` files, so adding an 8th plugin to the marketplace requires no edit to the skill or this command — they pick up the new plugin on the next invocation.
