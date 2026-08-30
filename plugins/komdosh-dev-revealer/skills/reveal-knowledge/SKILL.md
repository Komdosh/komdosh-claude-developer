---
name: reveal-knowledge
user-invocable: false
description: Multi-source retrieval over the project's accumulated knowledge — ADRs, specs, plans, notes, code-embedded decision comments, commit messages, and any RAG / MCP-backed knowledge bases the developer has wired up (codebase-memory-mcp, lookstream-code-rag, Confluence/Notion/Linear, context7, ref-context). Returns ranked snippets with source + date + excerpt. Read-only. Use when an agent or developer asks "have we decided this before", "what's the rationale for X", "show me prior work on Y".
---

# Reveal Knowledge

Surfaces what the project already knows, before something new gets decided. Read-only and stateless: it writes nothing, touches no index, invokes no agent.

Inputs: `query` · `scope` (any of `adr,specs,plans,notes,code,commits,mcp`; omitted = everything available) · `max_results` (default 15).

## 1. Detect what's actually available

Local: `docs/{adr,specs,plans,notes}`, other free-form `docs/*.md`, code annotations (`// DECISION|RATIONALE|NOTE|WHY:`), and git log.

MCP — probe each and mark **available** / **needs-auth** / **not-configured**: `codebase-memory` (`index_status`), `lookstream-code-rag` (`list_collections`), Confluence/Jira, Notion, Linear, `context7`, `ref-context`.

**Never block on needs-auth.** Note it in the skipped list and continue — the user authenticates outside this skill.

## 2. Search

- **Docs** — grep titles and bodies; capture path, first H1, mtime **and first-commit date** (`git log --diff-filter=A --follow`), and a short excerpt. For ADRs, pull `## Status` and `## Decision` specifically — those are the highest-value snippets.
- **Code annotations** — `grep -rnE '//\s*(DECISION|RATIONALE|NOTE|WHY):'` filtered by the query, with three lines of context.
- **Commits** — `git log --all --grep=<kw> -i`, fetching the body when the subject matches strongly.
- **MCP** — the semantic-search tool per source, budgeted at `max_results / available_sources`. Normalise everything to `{source, id_or_url, title, date, excerpt}`.

**A single source failing — rate limit, expired auth, network — is recorded under skipped and never aborts the run.**

Split the query on whitespace, drop stop-words, and for a multi-word concept grep both the phrase and the individual words.

## 3. Rank

Score in [0,1]: exact phrase in a title or heading +0.40 · in the body +0.20 · keyword density +0.10 · edited within 90 days +0.10 · source class (ADR > spec > plan > notes > code > commits > MCP-misc) +0.05–0.20 · an MCP's own score weighted 0.30.

**Dedupe across sources** — the same ADR indexed by an MCP is one hit; keep the higher score and note "also seen in".

## 4. Report

Cross-source **Top hits** with excerpt and score · a per-source breakdown · **sources skipped with reasons**, so the developer learns what they could enable · then a JSON tail (`query`, `scope`, `sources_searched`, `sources_skipped`, `total_hits`, `top_hit_ids`).

**Zero hits is a result, not a failure**: "no hits across N sources searched" means greenfield, and saying so is the point of the skill. Never fill the gap with an unsourced answer.

Exclude `build`, `node_modules`, and `.gradle` from local greps — they dominate the runtime on a large repo.
