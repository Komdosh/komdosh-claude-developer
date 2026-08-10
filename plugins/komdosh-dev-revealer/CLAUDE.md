# CLAUDE.md — komdosh-dev-revealer

Retrieval before invention. Two ladders, one discipline: **answer from a real source, cite it, and name the gaps instead of filling them.**

Both halves exist to stop the same failure — inventing an answer that sounds right. `/reveal` prevents re-deciding something the team already decided; `/doc-reveal` prevents recalling an API from training data that may have moved on.

## What it adds

| Command | Agent | Skill | Answers |
|---|---|---|---|
| [`/reveal <query>`](commands/reveal.md) | [`knowledge-revealer`](agents/knowledge-revealer.md) | [`reveal-knowledge`](skills/reveal-knowledge/SKILL.md) | *"What do we already know about X?"* — ADRs, specs, plans, notes, code-embedded `// DECISION` / `// RATIONALE` / `// WHY` comments, commit archaeology, and any RAG/MCP knowledge base wired up (codebase-memory, Confluence/Notion/Linear, context7, ref-context). |
| [`/doc-reveal <symbol\|topic\|library>`](commands/doc-reveal.md) | [`doc-revealer`](agents/doc-revealer.md) | [`reveal-source-docs`](skills/reveal-source-docs/SKILL.md) | *"What does this actually do?"* — in-repo KDoc/Javadoc, project `/docs/`, `~/.claude/docs-cache/`, MCP, canonical web docs, pre-indexed JAR listings, decompilation last. |

`/reveal` runs in three modes: **survey** (default — broad retrieval, topic-level synthesis), **decision-trace** (one decision and its history), **gap-find** (does prior work exist at all, oriented toward "should we write an ADR?").

## Big picture

Both ladders are **cheapest-source-first**: each rung is tried only when the one above it doesn't confidently answer, and the answer records which rung won. That ordering is the whole point — decompiling a JAR to learn a method signature that's in the KDoc three directories away is a real cost, and so is a WebSearch for something the project already documented.

`/doc-reveal` caches resolved snippets to `~/.claude/docs-cache/` so repeat queries are instant. It is the only thing here that writes anything, and it never writes to project source.

Both halves report **gaps explicitly**. "No prior work on X — consider an ADR" is a result, not a failure; an invented citation is the failure. Neither generates new knowledge: capturing a decision is core's `/adr-new`, and designing a feature is `/analyze-requirements` or delivery's `/implementation-plan`.

Both degrade gracefully when no MCP is configured — they say which sources were searched and which were skipped and why, rather than silently narrowing.

## Use it when

- Before drafting an ADR — has this been decided already?
- Before designing a feature — what specs, plans, or notes touch this area?
- During review, when a pattern's rationale isn't obvious from the code.
- Whenever you're about to state an API signature, config key, or library behaviour from memory.

## Boundary

- Read-only on project source. Never modifies code, never writes an ADR, never updates an index.
- Returns ranked snippets with source + date + excerpt, and a synthesis with inline citations. The caller decides what to do with them.
- Never fabricates a source, a symbol, or a quote. If it can't be grounded, it's reported as a gap.

## Dependencies

Requires `komdosh-dev-spring-core`. All MCP-backed sources are optional.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; both agents here set `disallowedTools` for the write tools).
- New skill → `skills/<name>/SKILL.md`.
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/jar-inspection.md
