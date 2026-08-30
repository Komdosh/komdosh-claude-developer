---
name: recommend-plugin
user-invocable: false
description: Read the current task from session context and recommend the single best komdosh-claude-developer plugin + agent/command/skill to invoke, with rationale and exact invocation. Triggers on "which plugin", "which agent", "which command", "is there a tool for", "what should I use for X", "how do I do X in this marketplace", or any moment a Claude session is uncertain which marketplace capability fits the task. Reads the marketplace catalog at runtime from marketplace.json + per-plugin plugin.json — never hand-maintained. Read-only.
---

# Recommend Plugin

Given the task in play, name the right plugin **and** the right entry point inside it. `lifecycle-status` answers "which gate are we on"; this answers "which capability solves this task".

Read-only: recommend, never invoke, never install.

Skip it when the user already named the exact entry point (just invoke it), when the task is outside the marketplace, or when `lifecycle-status` already produced a `next_recommended_gate` — follow that instead.

## The catalog is read at runtime

**Never hardcode the plugin list**, and never filter it to a subset of the naming scheme — `komdosh-dev-*` covers the Spring wave, `kotlin-extras`, `revealer`, and the three `infra-*` plugins alike. A narrower pattern silently makes whole plugins unrecommendable.

1. Locate `marketplace.json` under `~/.claude/plugins/marketplaces/…`; fall back to a bounded `find` for any `marketplace.json` listing a `komdosh-dev-*` plugin.
2. Enumerate installed plugins from `*/.claude-plugin/plugin.json` under `~/.claude/plugins` and its `cache`, keeping every `komdosh-dev-*` name with its `description` and `keywords`.
3. Plugins present in `marketplace.json` but not installed stay in the catalog, marked `installed: false`, so they can still be recommended with an install hint.

**If neither the marketplace file nor any installed plugin is found, say the catalog is unavailable and stop.** Do not reconstruct it from memory — a recommendation for a plugin that isn't there wastes the user's time twice.

## Choosing

Score each plugin: **strong** (the task's verb+noun is explicitly in its keywords or description) → primary · **domain** (right area, no named entry point) → medium · **weak** → alternate only. At most three plugins total.

Tie-breakers:

1. "Have we decided this / has this been done?" → `revealer` first, then come back here.
2. "What's next?" / session orientation → `/lifecycle`, not this skill.
3. Anything touching service code → `spring-core` applies; check whether a specialist layers on top.
4. Consumer plus a new table → `spring-core`'s `event-consumer-author` primary, `/add-migration` as follow-up.
5. QA artifacts for an endpoint not written yet → `spring-core` first, `spring-quality` after.
6. Vendor coupling in production code → `spring-quality`'s `/audit-leaks`.
7. Dependency bumps, flakes, load tests → `kotlin-extras`.
8. Manifests, Helm, ArgoCD, Terraform, cloud resources, secrets, infra PII → the `infra-*` plugins. **These are covered** — do not report them as a gap.
9. Genuinely nothing matches → say so plainly. Suggest `/adr-new` if the gap is architecturally significant.

## Entry point

Resolve from the installed plugin's own `commands/`, `agents/`, and `skills/` directories — the metadata names the plugin, not the hook. Prefer **command > agent > skill**: commands are user-facing, agents are delegation targets, skills are checklists.

For an uninstalled plugin you cannot inspect the directory — recommend at plugin level and say the entry point follows after install.

## Output

Task signal in one line · **Primary** as `<plugin>` → `<entry>` with the matching evidence quoted, the exact invocation, and installed yes/no with the install command · up to two alternates with a one-line reason each · confidence · caveats.

**Name the missing dependency explicitly** when the recommended plugin needs `komdosh-dev-spring-core` (or `komdosh-dev-infra-core`) and that is also absent — otherwise the install command the user copies will fail on its own.
