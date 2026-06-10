---
name: recommend-plugin
user-invocable: false
description: Read the current task from session context and recommend the single best komdosh-claude-developer plugin + agent/command/skill to invoke, with rationale and exact invocation. Triggers on "which plugin", "which agent", "which command", "is there a tool for", "what should I use for X", "how do I do X in this marketplace", or any moment a Claude session is uncertain which marketplace capability fits the task. Reads the marketplace catalog at runtime from marketplace.json + per-plugin plugin.json — never hand-maintained. Read-only.
---

# Recommend Plugin

A meta-advisor: given the current conversation's task signal, point the user (or another agent) at the right plugin + the right entry point inside it.

Complements `lifecycle-status` — that skill answers *"which gate are we on?"*; this one answers *"which marketplace capability solves this specific task?"*.

The catalog is **read at runtime** from the marketplace's `marketplace.json` and each installed plugin's `plugin.json` — adding a new plugin to the marketplace requires no edit here.

## When to Use

Use this skill when **any** of the following is true:

- The user asks "which plugin / agent / command / skill should I use for X?"
- The user describes a task ("I need to add a Kafka consumer", "I want to find vendor leaks", "we need a Postman collection") without naming a plugin.
- A subagent is uncertain whether a marketplace capability already exists for what it's about to hand-roll.
- A new conversation starts and the user names a goal the marketplace covers but doesn't reference a specific command.

Do NOT use when:

- The user has already named the exact command/agent/skill to invoke — just invoke it.
- The task is purely about non-marketplace concerns (general Kotlin questions, refactoring inside a single file, code review of a single function).
- `lifecycle-status` has already been called and emitted a `next_recommended_gate` — follow that instead.

Read-only. Never write files; never invoke other agents directly. Output a recommendation; the caller decides whether to act on it.

## Output

A short markdown block with a primary recommendation, up to two alternates, and an install hint if the recommended plugin isn't installed.

```markdown
## Plugin Recommendation

**Task signal:** <one-line restatement of what the user/agent appears to want>

**Primary:** `<plugin-name>` → `<command|agent|skill>`
- **Why:** <1–2 sentences citing the matching capability>
- **Invoke:** `/<command>` *(or)* delegate to agent `<agent-name>` *(or)* call skill `<skill-name>`
- **Installed:** ✅ yes  *(or)*  ❌ no — install with `/plugin install <plugin-name>@komdosh-claude-developer`

**Alternates (lower confidence):**
- `<other-plugin>` → `<entry>` — <one-line reason>

**Confidence:** high | medium | low
**Notes:** <any caveats — e.g. "requires core which is also missing", "task may need /lifecycle first">
```

If no marketplace capability matches: say so explicitly. Don't invent one.

## Disambiguation Rules

When two plugins look plausible, apply these tie-breakers (catalog-independent):

1. **"Should I do this?" or "have we done it?" before "do it"** → revealer (`/reveal`), then loop back here.
2. **"What's next?" or session-orientation** → orchestrator (`/lifecycle`), not this skill — re-route.
3. **Anything that touches code** → core almost always applies; check whether a more specialised plugin layers on top.
4. **Both events and core could apply** (e.g. "add a consumer that writes to a new table") → recommend events as primary, with core's `/add-migration` as a follow-up.
5. **Both qa and core could apply** (e.g. "regenerate the QA artifacts after my new endpoint") → core first if the endpoint isn't written yet, then qa.
6. **Vendor-coupling concern in production code** → platform.
7. **Dependency bump, flake hunting, load testing** → extras.
8. **No marketplace capability matches** → say so. Suggest `/adr-new` if the gap is architecturally significant, or admit it's outside the marketplace's scope.

## Steps

- [ ] **Step 1: Extract the task signal**

Read the most recent user message and the last 3–5 assistant turns. Form a one-line restatement of what the user/agent wants to accomplish. If the task is a multi-step request, focus on the *next single action*.

If the signal is ambiguous (no clear verb-noun, or a meta-question like "what can this marketplace do?"), prefer recommending `/lifecycle` (orchestrator) over guessing.

- [ ] **Step 2: Locate `marketplace.json`**

```bash
mp_paths=(
  "$HOME/.claude/plugins/marketplaces/komdosh-claude-developer/.claude-plugin/marketplace.json"
  "$HOME/.claude/plugins/marketplaces/komdosh/komdosh-claude-developer/.claude-plugin/marketplace.json"
)
mp_json=""
for p in "${mp_paths[@]}"; do
  [ -f "$p" ] && mp_json="$p" && break
done
# Fallback: deep-find under ~/.claude/plugins (any marketplace.json that lists this owner's plugins).
if [ -z "$mp_json" ]; then
  mp_json=$(find "$HOME/.claude/plugins" -maxdepth 6 -type f -name marketplace.json 2>/dev/null \
    | xargs -I{} sh -c 'jq -e ".plugins[]? | select(.name | test(\"^komdosh-dev-(spring|kotlin)-\"))" "{}" >/dev/null 2>&1 && echo "{}"' \
    | head -1)
fi
echo "marketplace.json: ${mp_json:-NOT FOUND}"
```

If `marketplace.json` is found, parse `.plugins[]` for `name`, `description`. (Marketplace JSON's per-plugin description is short and value-prop; combine with each plugin's `plugin.json` for keywords + full description.)

- [ ] **Step 3: Detect installed plugins + read their metadata**

```bash
plugin_dirs=(
  "$HOME/.claude/plugins"
  "$HOME/.claude/plugins/cache"
)
declare -A installed plugin_path
while IFS= read -r line; do
  : # consume — populated below
done < /dev/null

for d in "${plugin_dirs[@]}"; do
  [ -d "$d" ] || continue
  # Match both namespace prefixes: spring-* (Spring-specific plugins) and kotlin-* (generic Kotlin/JVM plugins).
  while IFS= read -r found; do
    name=$(jq -r '.name // empty' "$found/.claude-plugin/plugin.json" 2>/dev/null)
    [ -n "$name" ] || continue
    [[ "$name" == komdosh-dev-spring-* || "$name" == komdosh-dev-kotlin-* ]] || continue
    installed[$name]=1
    plugin_path[$name]="$found"
  done < <(find "$d" -maxdepth 4 -type d \( -name 'komdosh-dev-spring-*' -o -name 'komdosh-dev-kotlin-*' \) 2>/dev/null)
done

# For each installed plugin, emit name + description + keywords as a JSON line.
for name in "${!installed[@]}"; do
  jq -c --arg n "$name" '{name: $n, description, keywords}' \
    "${plugin_path[$name]}/.claude-plugin/plugin.json" 2>/dev/null
done
```

For each plugin in `marketplace.json` that is **not** in `installed`, also emit `{name, description, keywords: null, installed: false}` so it can still be recommended (with an install hint).

If neither `marketplace.json` nor any installed plugin is found (typical in a sandbox), emit one line:
```text
Catalog unavailable — no marketplace.json located and no komdosh-dev-{spring,kotlin}-* plugins installed under ~/.claude/plugins.
```
…and stop. Don't fabricate recommendations from training-data memory.

- [ ] **Step 4: Score the catalog against the task signal**

For each plugin in the catalog, score the match using:

- **Strong match** (high confidence): the task signal contains a verb+noun phrase the plugin's `keywords` or `description` covers explicitly (e.g. "add Kafka consumer" ↔ keywords `["kafka", "consumer"]`).
- **Domain match** (medium confidence): the task is in the plugin's domain but doesn't name a specific entry point.
- **Weak match** (low confidence): tangential overlap; flag as alternate, not primary.

Apply the **Disambiguation Rules** above when two rows tie. Use the plugin's `description` for entry-point hints when the keywords are too coarse.

- [ ] **Step 5: Map the chosen plugin to its entry points**

The plugin metadata names the plugin but not which command/agent/skill is the right hook. Resolve from the plugin's directory:

```bash
plugin_dir="${plugin_path[$chosen]}"
[ -d "$plugin_dir/commands" ] && ls "$plugin_dir/commands/"  # available slash commands
[ -d "$plugin_dir/agents" ]   && ls "$plugin_dir/agents/"    # available agents
[ -d "$plugin_dir/skills" ]   && ls "$plugin_dir/skills/"    # available skills
```

For an uninstalled plugin, you cannot inspect its directory locally — recommend at the plugin level only and say "after install, run the matching command (typically `/<verb-noun>` — see the plugin's CLAUDE.md)".

Pick the entry point that names the verb in the task signal most directly. Prefer the order: **command > agent > skill**. Commands are user-facing; agents are delegation targets; skills are checklists.

- [ ] **Step 6: Pick primary + up to two alternates**

The primary is the highest-confidence match. Alternates are weaker matches the user might prefer if they have additional constraints. Never recommend more than three plugins total.

If the task is genuinely outside the marketplace, output one explicit "no match" line per the Disambiguation Rules.

- [ ] **Step 7: Emit the recommendation block**

Use the markdown shape from the **Output** section. Be exact:

- Cite the plugin name in full so the install hint copy-pastes cleanly.
- Cite the entry point in the same form the user would type (`/add-endpoint`, agent `backend-implementer`, skill `coroutine-safety-scan`).
- If the recommended plugin is not installed, append the install command. If the *required dependency* (`komdosh-dev-spring-core`) is also missing, mention that explicitly — the user has to install core first.

## Examples

**Example 1 — clear keyword match, plugin not installed.**

> User: "I need to add a Kafka consumer for the order-events topic."

```markdown
## Plugin Recommendation

**Task signal:** add a Kafka consumer for the `order-events` topic.

**Primary:** `komdosh-dev-spring-events` → agent `event-consumer-author`
- **Why:** matched on plugin keywords `["kafka", "consumer"]` and description "Kafka / SQS / RabbitMQ consumer authoring … manual offset/ack, mandatory idempotency".
- **Invoke:** delegate to agent `event-consumer-author`
- **Installed:** ❌ no — install with `/plugin install komdosh-dev-spring-events@komdosh-claude-developer`

**Alternates (lower confidence):**
- `komdosh-dev-spring-core` → `/add-migration` — if the consumer needs a `processed_events` table, run this after.

**Confidence:** high
```

**Example 2 — orientation, not a task.**

> User: "Where are we on this branch?"

```markdown
## Plugin Recommendation

**Task signal:** orient on current branch state — gate status, what's next.

**Primary:** `komdosh-dev-spring-orchestrator` → `/lifecycle status`
- **Why:** disambiguation rule #2 — "what's next?" is the orchestrator's job, not this skill's.
- **Invoke:** `/lifecycle status` (or `/lifecycle next` for the recommended next action)
- **Installed:** ✅ yes

**Confidence:** high
```

**Example 3 — no match.**

> User: "Can you help me write a Helm chart for this service?"

```markdown
## Plugin Recommendation

**Task signal:** author a Helm chart for the service.

**No marketplace capability matches.** None of the installed/known plugins' keywords or descriptions cover Kubernetes/Helm packaging. Suggest:
- Open an ADR if a packaging convention doesn't exist yet (`/adr-new`, requires `komdosh-dev-spring-core`).
- Otherwise proceed with a general Claude Code workflow.

**Confidence:** high (that no plugin matches)
```

**Example 4 — disambiguation between core and qa.**

> User: "I added an endpoint, now I want a checklist for the testers."

```markdown
## Plugin Recommendation

**Task signal:** generate a manual QA checklist that covers the new endpoint.

**Primary:** `komdosh-dev-spring-qa` → `/qa-plan`
- **Why:** matched on keywords `["qa", "manual-testing"]`; the plugin's commands directory contains `qa-plan.md`, which generates a markdown checklist via the shared `discover-api-surface` skill.
- **Invoke:** `/qa-plan`
- **Installed:** ✅ yes

**Alternates (lower confidence):**
- `komdosh-dev-spring-qa` → `/qa-postman` — if a Newman-runnable smoke suite is more useful than a checklist.
- `komdosh-dev-spring-qa` → `/qa-console` — if a non-CLI teammate needs a clickable HTML tester.

**Confidence:** high
```

## What this skill is NOT

- Not a replacement for `/lifecycle next` — that recommends the next *gate*; this skill recommends the right *plugin* for an explicit task.
- Not a knowledge-base lookup — for "have we decided X?" route to the revealer plugin.
- Not an installer — surface install commands but don't run them; `/plugin install …` is a user action.
- Not a task router that invokes the recommendation — the caller decides whether to act.
- Not a hand-maintained catalog — the plugin list is read at runtime from `marketplace.json` and per-plugin `plugin.json` files, so the skill stays in sync with the marketplace automatically.
