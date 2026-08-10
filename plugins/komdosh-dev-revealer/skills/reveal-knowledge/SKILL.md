---
name: reveal-knowledge
user-invocable: false
description: Multi-source retrieval over the project's accumulated knowledge — ADRs, specs, plans, notes, code-embedded decision comments, commit messages, and any RAG / MCP-backed knowledge bases the developer has wired up (codebase-memory-mcp, lookstream-code-rag, Confluence/Notion/Linear, context7, ref-context). Returns ranked snippets with source + date + excerpt. Read-only. Use when an agent or developer asks "have we decided this before", "what's the rationale for X", "show me prior work on Y".
---

# Reveal Knowledge

## When to Use

Run this skill whenever an agent (or the developer) wants to surface accumulated project knowledge before making a new decision or starting a new piece of work. Examples:

- Before drafting an ADR — has this decision been made before?
- Before designing a feature — what specs / plans / notes touch this area?
- During a code review — what's the documented rationale for the pattern under question?
- When debugging an unfamiliar abstraction — who designed it and why?

Read-only. This skill never writes files, never modifies indexes, and never invokes other agents. The calling agent decides what to do with the results.

## Inputs

- `query` (required) — natural-language topic or question. Examples: "caching strategy", "why we chose jOOQ over Exposed", "outbox pattern decisions", "rate limiting".
- `scope` (optional) — comma-separated list to narrow sources:
  - `adr` — only `docs/adr/`
  - `specs` — only `docs/specs/`
  - `plans` — only `docs/plans/`
  - `notes` — only `docs/notes/` and other free-form docs
  - `code` — only code-embedded comments tagged `// DECISION:`, `// NOTE:`, `// RATIONALE:`, `// WHY:`
  - `commits` — only git log
  - `mcp` — only MCP-backed sources (codebase-memory, lookstream-code-rag, Confluence, Notion, Linear, context7, ref-context)
  - (omitted) — search every available source
- `max_results` (optional, default 15) — cap the per-source result count.

## Output

A markdown report with one section per source that returned hits, then a synthesised "Top hits" section ranked across all sources.

```markdown
## Reveal: "<query>"
Scope: <list> · Sources searched: <list> · Sources skipped: <list with reasons>

### Top hits (ranked across all sources)
1. **ADR-0007 — Outbox pattern for cross-service events** (docs/adr/0007-outbox-pattern.md, 2025-11-12)
   > "We chose the outbox pattern over direct Kafka publish because the existing transaction model …"
   Score: 0.94

2. **Code: `OrderService.kt:142`** (// RATIONALE: …)
   > "// RATIONALE: outbox row is inserted in the same TX as the domain write; the relay polls and publishes async."
   Score: 0.81

3. **Confluence: "Order Service Architecture"** (mcp://atlassian/page/12345, last edited 2025-10-03)
   > "All async cross-service events go through outbox. See ADR-0007 for the decision."
   Score: 0.77

(... up to max_results ...)

### By source

#### docs/adr/ (3 hits)
- ADR-0007 — Outbox pattern for cross-service events (2025-11-12)
- ADR-0012 — Outbox poll interval tuning (2026-02-04)
- ADR-0019 — Outbox retention policy (2026-04-22)

#### docs/specs/ (1 hit)
- 2025-10-15-payments-async.md — references outbox in section "Event flow"

#### Code annotations (5 hits)
- adapters/outbound/orders/OrderRepository.kt:88 — // DECISION: …
- adapters/outbound/orders/OrderRepository.kt:142 — // RATIONALE: …
- ...

#### MCP: codebase-memory-mcp (2 hits)
- search_code returned: ...

#### MCP: Confluence (atlassian) (1 hit)
- "Order Service Architecture" — page 12345

#### Sources skipped
- MCP: lookstream-code-rag — not configured for this project (no collection found)
- MCP: Notion — authentication required (run mcp__plugin_engineering_notion__authenticate)
```

After the report, a structured JSON tail (the calling agent parses):

```json
{
  "query": "<query>",
  "scope": "<scope>",
  "sources_searched": ["adr", "specs", "code", "commits", "mcp:codebase-memory-mcp", "mcp:atlassian"],
  "sources_skipped":  ["mcp:lookstream-code-rag (not configured)", "mcp:notion (not authenticated)"],
  "total_hits": 12,
  "top_hit_ids": ["adr/0007", "code/OrderService.kt:142", "atlassian/page/12345"]
}
```

## Steps

- [ ] **Step 1: Detect available sources**

Local sources (always available if directories exist):

```bash
[ -d docs/adr ]    && echo "adr"
[ -d docs/specs ]  && echo "specs"
[ -d docs/plans ]  && echo "plans"
[ -d docs/notes ]  && echo "notes"
# free-form docs (anything else under docs/ that's not adr/specs/plans/notes/qa)
find docs -maxdepth 2 -name '*.md' -not -path '*/adr/*' -not -path '*/specs/*' \
  -not -path '*/plans/*' -not -path '*/notes/*' -not -path '*/qa/*' 2>/dev/null \
  | head -1 | grep -q . && echo "docs-misc"
# code annotations: present if at least one file has any of the markers
grep -rlE '//\s*(DECISION|RATIONALE|NOTE|WHY|TODO):' --include='*.kt' --include='*.java' . 2>/dev/null \
  | head -1 | grep -q . && echo "code"
# commits: always (assuming a git repo)
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "commits"
```

MCP sources (probe each — present iff the MCP tool is callable):

| MCP source | Tool to probe |
|---|---|
| codebase-memory | `mcp__codebase-memory-mcp__index_status` (returns project status if registered) |
| lookstream-code-rag | `mcp__lookstream-code-rag__list_collections` (returns at least one collection) |
| Confluence / Jira | `mcp__plugin_engineering_atlassian__*` (probe one tool; if it errors with auth-required, mark "needs auth") |
| Notion | `mcp__plugin_engineering_notion__*` |
| Linear | `mcp__plugin_engineering_linear__*` |
| context7 | `mcp__context7__resolve-library-id` (always available if MCP server is up) |
| ref-context | `mcp__ref-context__ref_search_documentation` |

For each MCP source, mark **available**, **needs-auth**, or **not-configured**. Do NOT block on `needs-auth` — note it in the skipped list and move on; the user authenticates outside this skill.

If `scope` was provided, intersect the available list with the requested scope.

- [ ] **Step 2: Search local file sources**

For each of `adr`, `specs`, `plans`, `notes`, `docs-misc`:

```bash
# Title-line + body grep
grep -rilE "<query-keywords>" docs/<scope>/ 2>/dev/null
# also: grep within front-matter / first heading
```

For each match, extract:
- file path
- first H1 heading (= title)
- file mtime + first commit date (`git log --diff-filter=A --follow --format=%ad --date=short -- <path> | tail -1`)
- a 2-3 line excerpt around the first match

For ADRs specifically, also parse the `## Status` and `## Decision` sections — those are the highest-value snippets.

- [ ] **Step 3: Search code annotations**

```bash
grep -rnE '//\s*(DECISION|RATIONALE|NOTE|WHY|TODO):' --include='*.kt' --include='*.java' . \
  | grep -iE "<query-keywords>"
```

For each hit, capture file:line + the comment (read 3 lines context).

- [ ] **Step 4: Search commit messages**

```bash
git log --all --grep="<query-keyword>" -i --format='%H|%ad|%s|%an' --date=short \
  | head -<max_results>
```

For each hit, capture SHA + date + subject + author. Optionally fetch the commit body (`git log -1 --format=%B <SHA>`) for richer context if the subject matches strongly.

- [ ] **Step 5: Search MCP sources (only those marked available)**

For each available MCP source, call its semantic search tool with the query. Limit results per source to `max_results / available_sources` (round up).

| MCP | Call shape |
|---|---|
| codebase-memory | `mcp__codebase-memory-mcp__search_code` (pattern, scope) — for code+graph hits |
| codebase-memory | `mcp__codebase-memory-mcp__manage_adr` (action: list/search) — for ADR-aware queries |
| lookstream-code-rag | `mcp__lookstream-code-rag__semantic_search` (query, top_k) |
| lookstream-code-rag | `mcp__lookstream-code-rag__contextual_search` (query, context) — when the query is open-ended |
| Confluence | search via `mcp__plugin_engineering_atlassian__*` (the actual tool name varies — probe and pick the search-style one) |
| Notion | similar |
| Linear | similar |
| context7 | `mcp__context7__resolve-library-id` if the query mentions a library |
| ref-context | `mcp__ref-context__ref_search_documentation` for general docs |

For each result, normalise to: `{ source, id_or_url, title, date, excerpt }`.

If a tool errors (rate-limited, auth-expired, network), record it under `sources_skipped` with a one-line reason and move on. Never abort the whole skill on a single source failure.

- [ ] **Step 6: Score and rank**

Per hit, compute a relevance score in [0, 1]:

| Signal | Weight |
|---|---|
| Exact phrase match in title / heading | +0.40 |
| Exact phrase match in body | +0.20 |
| Keyword density (matches per 1000 chars) | +0.10 × normalised |
| Recency (within last 90 days) | +0.10 |
| Source-class boost (ADR > spec > plan > notes > code > commits > MCP-misc) | +0.05 to +0.20 |
| MCP semantic-search returned score (if provided) | use as-is, weight 0.30 |

Sum and clamp to [0, 1]. Sort descending. Take the top `max_results` for the "Top hits" section; render the rest under "By source".

Dedupe: if the same conceptual hit shows up from two sources (e.g., ADR file + an MCP-indexed copy of the same file), keep the higher-scored one and note the second under "Also seen in".

- [ ] **Step 7: Compose the report**

Render per the Output format. Include:

- The "Top hits" cross-source ranking
- Per-source breakdown
- Sources skipped (with reasons — this lets the developer know what they could enable)
- The JSON tail

If `total_hits == 0`, state: "No hits across <N> sources searched. Sources skipped: <list>." This is itself useful information — "no prior work on this" means the developer is in greenfield territory.

## Notes

- This skill is read-only and stateless. It does not cache results across invocations. For expensive RAG-backed sources, the calling agent may want to deduplicate calls within a session.
- The keyword-extraction step (Step 2's "<query-keywords>") should split the natural-language query on whitespace and drop stop-words (`a`, `the`, `we`, `is`, etc.). For multi-word concepts ("outbox pattern"), grep both the phrase and each word individually.
- For Confluence / Notion / Linear: the user must have authenticated the corresponding MCP server (e.g. `/mcp__plugin_engineering_atlassian__authenticate`). The skill detects unauthenticated state and reports it under `sources_skipped` rather than failing.
- For very large repos, the local greps can be slow. Pass `--exclude-dir=build --exclude-dir=node_modules --exclude-dir=.gradle` (already in `settings.recommended.json` for the equivalent permissions).
- This skill complements (not replaces) the agents that GENERATE knowledge — `/adr-new` (in core), `/analyze-requirements` (in core), `code-reviewer` (in core). Use those when something new needs to be written; use this when you want to find what's already been written.
