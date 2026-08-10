# /reveal &lt;query&gt; [--mode=survey|decision-trace|gap-find] [--scope=&lt;sources&gt;]

Reveal what the project already knows about a topic — across ADRs, specs, plans, notes, code-embedded decision comments, commit archaeology, and any RAG/MCP-backed knowledge bases the developer has wired up. Returns a synthesised answer with citations, a list of gaps, and one recommended next step.

## Usage

```text
/reveal caching strategy
/reveal "why did we pick jOOQ over Exposed" --mode=decision-trace
/reveal outbox pattern --mode=gap-find
/reveal rate limiting --scope=adr,specs                    # only docs
/reveal correlation id propagation --scope=code,commits    # only code + git log
/reveal --scope=mcp service mesh policy                    # MCP-backed sources only
```

The `--mode` and `--scope` flags can appear in any position; the rest of the line is the query.

## Modes

- `survey` (default) — broad overview of what's known on the topic
- `decision-trace` — pinpoint a single decision and its history, chronologically
- `gap-find` — directly answer "is there prior work?" and recommend the right next step

## Scopes

- `adr` — only `docs/adr/`
- `specs` — only `docs/specs/`
- `plans` — only `docs/plans/`
- `notes` — only free-form `docs/` markdown
- `code` — only code-embedded `// DECISION:` / `// RATIONALE:` / `// NOTE:` / `// WHY:` comments
- `commits` — only git log
- `mcp` — only MCP-backed sources (codebase-memory, lookstream-code-rag, Confluence, Notion, Linear, context7, ref-context)
- (omitted) — every available source

## Steps

- [ ] **Step 1: Parse args**

Extract `--mode=...` and `--scope=...` from the args (any position). Treat the remainder as the natural-language query. If the query is empty after parsing, ask: "What topic should I reveal?"

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 3: Invoke `knowledge-revealer`**

Pass `query`, `mode`, and `scope` (any unset). The agent:
1. Refines the query into a focused 3–8 word phrase.
2. Runs the `reveal-knowledge` skill (multi-source retrieval with graceful MCP fallback — never fails on unconfigured/unauthenticated sources, just notes them in `sources_skipped`).
3. Synthesises 2–6 sentences answering the question, citing top hits inline.
4. Lists gaps explicitly (no ADR / source not authenticated / stale info / contradiction).
5. Recommends exactly one next step.

- [ ] **Step 4: Report**

Print the agent's full output verbatim. Inline citations make the answer auditable; do not summarise away the citations.

- [ ] **Step 5: Suggest follow-up**

The agent itself recommends one concrete next step. Surface it. If the agent's recommendation is `/adr-new`, suggest the user might also want to run `check-adr-required` first to confirm the threshold is met (saves writing an ADR for a decision that doesn't warrant one).

## Notes

- This command is read-only — it never modifies code, never authenticates MCP servers, never writes new docs. The follow-up actions it recommends will.
- Quality of revealing is bounded by the quality of your knowledge base. If `docs/adr/` is empty and no MCP knowledge base is wired up, expect "no prior work" answers frequently — that's accurate; start writing ADRs (`/adr-new`).
- For multi-topic queries (`/reveal caching AND rate limiting`), the agent will pick the first topic and note that the other was deferred. Re-run the command for each topic.
