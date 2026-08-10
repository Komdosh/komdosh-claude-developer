# /doc-reveal &lt;query&gt; [--kind=auto|internal|library|architecture] [--depth=summary|full] [--no-web] [--no-cache] [--refresh]

Reveal **source documentation** for a symbol, topic, framework, library, or open-source project — using the cheapest source first (in-repo KDoc/Javadoc → project `/docs/` → `~/.claude/docs-cache/` → MCP `context7` / `ref-context` / `codebase-memory` → canonical web docs via WebFetch with WebSearch fallback → pre-indexed JAR listings → JAR decompilation as edge-case-only last resort). Caches every successful fetch so repeat lookups are instant.

This is the **smart alternative to "let me decompile the JAR"**. Decompilation is the last step on the ladder, not the first.

## Usage

```text
/doc-reveal OrderRepository                                       # internal class
/doc-reveal Mono.transform                                        # library symbol
/doc-reveal Mono.transform --depth=full                           # full sections, not just summary
/doc-reveal "Spring WebFlux WebFilter ordering"                   # topic / multi-word
/doc-reveal kotlinx.coroutines.flow.flowOn --refresh              # force re-fetch + cache overwrite
/doc-reveal com.example.orders --kind=architecture                # package-level docs
/doc-reveal "jOOQ R2DBC connection pool" --no-web                 # offline / strict mode
/doc-reveal SecurityWebFilterChain --no-cache                     # skip cache read; still write fresh entry
```

The flags can appear in any position; the rest of the line is the query.

## What it does, briefly

The command runs the `doc-revealer` agent, which:

1. Classifies the query (internal / library / architecture).
2. Walks a 10-step source ladder via the `reveal-source-docs` skill — stopping at the first source that confidently answers.
3. Synthesises a focused answer with verbatim signatures and inline anchors.
4. Writes a Markdown cache entry under `~/.claude/docs-cache/` for future lookups.
5. Surfaces provenance, related symbols, and any gaps (empty KDoc, missing MCP, version mismatch, JAR-decompile fallback).

The agent **never modifies project source code** and only writes to `~/.claude/docs-cache/`.

## Flags

| Flag | Meaning |
|---|---|
| `--kind=auto` (default) | Let the agent classify. Fully-qualified names that start with the service's base package → `internal`; "architecture" / "module" / "boundary" → `architecture`; otherwise → `library`. |
| `--kind=internal` | Force the in-repo KDoc/Javadoc step first. Use when you know the symbol is yours. |
| `--kind=library` | Force the library ladder. Use when you have a class name shared with one of yours but want the upstream doc. |
| `--kind=architecture` | Force the project `/docs/` step first. Use for package- / module- / pattern-level questions. |
| `--depth=summary` (default) | 2–6 sentences + key signatures. Cheap. |
| `--depth=full` | Verbatim sections grouped by anchor. Use on the first lookup of a class you'll keep coming back to — the cache will then satisfy summaries without re-fetching. |
| `--no-web` | Stop the ladder after the MCP step. Useful offline or when WebFetch is rate-limited. |
| `--no-cache` | Bypass the cache *read*. The agent still *writes* a fresh entry (unless `--refresh` is also off and the existing entry is current). |
| `--refresh` | Force a re-fetch and overwrite the cached entry. Use after a library upgrade or when you suspect the cache is stale. |

## Source ladder (cheapest → most expensive)

| # | Source | Wins for |
|---|---|---|
| 1 | In-repo KDoc / Javadoc | Internal symbols. |
| 2 | Project `/docs/` (architecture, module, package) | Architecture, "why this pattern". |
| 3 | `~/.claude/docs-cache/` | Repeat lookups. Instant. |
| 4 | MCP `mcp__codebase-memory-mcp__*` (`get_code_snippet`, `get_architecture`) | Indexed-graph-accurate internal lookups. |
| 5 | MCP `mcp__context7__*` | Up-to-date library / framework reference docs. |
| 6 | MCP `mcp__ref-context__*` | General docs search fallback. |
| 7 | WebFetch on canonical URLs (`docs.spring.io`, `javadoc.io`, `kotlinlang.org/api`, GitHub README/wiki) | Library has known canonical layout. |
| 8 | WebSearch → WebFetch | URL unknown — search first, then fetch. |
| 9 | Pre-indexed JAR listings under `~/.claude/jar-cache/listings/` | "What package contains this class?" |
| 10 | JAR decompilation (edge case only) | Nothing else has the answer. Output flags the source so the developer knows the answer is bytecode-derived. |

`--no-web` cuts the ladder at step 6; everything else still runs.

## Steps

- [ ] **Step 1: Parse args**

Extract `--kind=`, `--depth=`, `--no-web`, `--no-cache`, `--refresh` from any position. Treat the remainder as the query. If the query is empty after parsing, ask: "Which symbol / topic / library should I reveal?"

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session. Required so the agent can distinguish internal package prefixes from external libraries.

- [ ] **Step 3: Invoke `doc-revealer`**

Pass `query`, `kind`, `depth`, `no_web`, `no_cache`, `refresh`. The agent runs the ladder via the `reveal-source-docs` skill and synthesises the result.

- [ ] **Step 4: Report**

Print the agent's full output verbatim — Summary, Key signatures, Provenance, Related, Gaps. Do not summarise away the signatures or the provenance; they are the highest-value content.

- [ ] **Step 5: Surface follow-ups**

If the agent's output flagged a gap that has a clean follow-up command, surface it on a single line *after* the agent output:

| Gap | Follow-up |
|---|---|
| Internal KDoc empty / one-liner | "Tip: ask `backend-implementer` to add a KDoc to `<class>` using the summary above as the seed." |
| Cached entry is older than the project's pinned version | "Tip: re-run with `--refresh` after the next dependency bump." |
| JAR decompilation was used | "Tip: this answer is bytecode-derived; treat with care. If a public Javadoc URL exists, point me at it and I'll re-cache." |
| Context7 / ref-context MCP not wired up | "Tip: install the MCP (Claude Code marketplace → context7 / ref-context) and re-run `/doc-reveal` to use it." |
| The query also looks like a project decision | "If you want the rationale (not the API), try `/reveal <topic>` (knowledge-revealer)." |

## Notes

- Read-only on project source. Only writes under `~/.claude/docs-cache/`.
- The plugin ships its own [`rules/jar-inspection.md`](../rules/jar-inspection.md) (loaded via the plugin's CLAUDE.md): never `jar tf` a pre-indexed JAR — the skill uses the listings under `~/.claude/jar-cache/listings/` instead. The listings directory is opt-in; if absent, steps 9–10 skip gracefully.
- For `context7` lookups: always start with `resolve-library-id` and pass the **full** question to `query-docs`, not single keywords (the skill enforces this).
- Distinct from `/reveal` (in `komdosh-dev-revealer`): `/reveal` answers "what have we already decided?"; `/doc-reveal` answers "what does this *mean* / how do I use it?". They are complementary; if you're not sure which you want, run `/reveal` first — if it returns "no prior work", come here.
