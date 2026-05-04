# CLAUDE.md — komdosh-dev-spring-revealer

This plugin reveals accumulated project knowledge — what you've already decided, written, and committed — across every available source. Targeted at advanced AI users who wire up RAG / MCP knowledge bases on top of the local docs.

## What it adds

| Item | Purpose |
|---|---|
| Command [`/reveal`](commands/reveal.md) | `/reveal <query> [--mode=survey\|decision-trace\|gap-find] [--scope=adr,specs,code,...]` |
| Agent [`knowledge-revealer`](agents/knowledge-revealer.md) | Three modes — Survey (broad overview), Decision-trace (chronological history of one decision), Gap-find (is there prior work? if not, recommend `/adr-new`). Synthesises 2–6 sentences answering the question with inline citations. Always lists gaps explicitly and recommends exactly one next step. |
| Skill [`reveal-knowledge`](skills/reveal-knowledge/SKILL.md) | Read-only multi-source retrieval. Searches local files (ADRs, specs, plans, notes, free-form docs, code-embedded `// DECISION:` / `// RATIONALE:` / `// NOTE:` / `// WHY:` comments, commit messages) and any MCP-backed source the developer has wired up. Detects what's available and skips inapplicable / unauthenticated sources gracefully — never fails on a single source. |

## Sources searched (when available)

| Source | Detection | Notes |
|---|---|---|
| `docs/adr/` | directory exists | ADRs parsed for `## Status` and `## Decision` blocks (highest-value snippets) |
| `docs/specs/` | directory exists | Spec docs |
| `docs/plans/` | directory exists | Implementation plans |
| `docs/notes/` and other free-form `docs/*.md` | files exist | Misc notes |
| Code annotations | grep finds `//\s*(DECISION\|RATIONALE\|NOTE\|WHY\|TODO):` | All Kotlin/Java |
| Commit messages | git repo | `git log --grep=` + body fetch on strong matches |
| `mcp__codebase-memory-mcp__*` | tool callable | Code+graph search; ADR-aware via `manage_adr` |
| `mcp__lookstream-code-rag__*` | at least one collection exists | Semantic + contextual search |
| `mcp__plugin_engineering_atlassian__*` | tool callable | Confluence + Jira (auth required — skipped with a hint if not authenticated) |
| `mcp__plugin_engineering_notion__*` | tool callable | Notion (auth required) |
| `mcp__plugin_engineering_linear__*` | tool callable | Linear tickets (auth required) |
| `mcp__context7__*` | tool callable | External library docs (use when query mentions a library) |
| `mcp__ref-context__*` | tool callable | General docs search |

## Output

Synthesised answer in 2–6 sentences, with inline citations `[1]` `[2]` `[3]`. Followed by:

- **Citations** — full source + date + key excerpt + link/path for each `[N]`
- **What this is missing** — gaps (no ADR, MCP not authenticated, stale info, contradictory sources)
- **Recommended next step** — exactly one concrete action

## Modes

- `survey` (default) — broad topic overview
- `decision-trace` — chronological history of a single decision (when proposed, who decided, alternatives rejected, consequences documented)
- `gap-find` — direct YES / PARTIAL / NO answer, oriented toward "should we write a new ADR?"

## Dependencies

Required: `komdosh-dev-spring-core` — for `read-service-context`, `check-adr-required`, and `adr-writer` (the recommended follow-up when a gap is found).

Optional: any MCP server that exposes searchable knowledge. The plugin gracefully degrades — without any MCP, it still works on local files + git log.

## Why a separate plugin

Knowledge revealing is a distinct capability from knowledge generation (which lives in core via `adr-writer`, `requirements-analyst`, `change-reviewer`). Some teams have rich MCP-backed knowledge bases and want first-class search; others rely on a small local `docs/adr/` and don't need this. Separating it as an opt-in plugin honours both, and lets the MCP-backed source detection evolve independently.
