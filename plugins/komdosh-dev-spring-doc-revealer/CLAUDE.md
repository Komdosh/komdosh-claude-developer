# CLAUDE.md — komdosh-dev-spring-doc-revealer

This plugin reveals **source documentation** — KDoc/Javadoc on classes, project `/docs/` architecture material, framework/library reference docs, and open-source READMEs/wikis. It is the *smart* alternative to "let me just decompile the JAR and read the bytecode": the agent targets the cheapest, most accurate source first, caches what it finds, and only falls back to JAR inspection when everything else fails.

## What it adds

| Item | Purpose |
|---|---|
| Command [`/doc-reveal`](commands/doc-reveal.md) | `/doc-reveal <symbol\|topic\|library>[#anchor] [--kind=auto\|internal\|library\|architecture] [--depth=summary\|full] [--no-web] [--no-cache] [--refresh]` |
| Agent [`doc-revealer`](agents/doc-revealer.md) | Classifies the query (internal symbol vs library API vs concept vs architecture), picks the right source ladder, fetches and synthesises a focused answer with anchors, and updates the local cache for repeat queries. Read-only on project files; only writes under `~/.claude/docs-cache/`. |
| Skill [`reveal-source-docs`](skills/reveal-source-docs/SKILL.md) | The source ladder + cache protocol. Detects what is available, runs the cheapest source first, normalises results, writes cache entries, and reports which source served the answer (so the developer can pre-warm or wire up better sources). |

## Source ladder (cheapest → most expensive)

The agent walks this ladder **in order**, stopping as soon as it has a confident answer at the requested `--depth`. Every step that succeeds writes a cache record so the next identical query is instant.

| # | Source | Detection | When it wins |
|---|---|---|---|
| 1 | **In-repo KDoc / Javadoc** | grep on `*.kt` / `*.java` for `/** ... */` blocks attached to the symbol | The symbol lives in this project. Always cheapest. |
| 2 | **Project `/docs/`** | `docs/architecture*.md`, `docs/<module>.md`, `README.md`, package-level `package-info.kt` / `package.md` | Architecture, module purpose, "why we wrote this class". |
| 3 | **`~/.claude/docs-cache/`** | the cache index has an entry for `<library>:<symbol-or-topic>` with TTL not expired | Repeat lookups for popular symbols. |
| 4 | **MCP `mcp__codebase-memory-mcp__*`** | tool callable + project indexed | Symbol exists in the indexed graph — `get_code_snippet(qualified_name)` returns the source + nearby doc comments without reading whole files. |
| 5 | **MCP `mcp__context7__*`** | tool callable | Up-to-date library / framework reference docs. The tool resolves `library-id` then queries scoped to the user's question. Best for Spring Boot / Reactor / Kotlin coroutines / kotlinx.serialization / etc. |
| 6 | **MCP `mcp__ref-context__*`** | tool callable | General docs search when context7 has no match (e.g. niche libraries, articles). |
| 7 | **WebFetch on canonical URLs** | derived from a small URL template table (see below) | Library has known canonical doc layout — `docs.spring.io/spring-framework/<v>/reference/<topic>.html`, `javadoc.io/doc/<group>/<artifact>/<v>/<class>.html`, `kotlinlang.org/api/...`, `github.com/<org>/<repo>#readme`, GitHub Wiki. |
| 8 | **WebSearch** | always available | Last-resort: query Google for `<symbol> <library> documentation` to discover a doc URL, then WebFetch it. |
| 9 | **Pre-indexed JAR listings** at `~/.claude/jar-cache/listings/` | listing file present per this plugin's [`rules/jar-inspection.md`](rules/jar-inspection.md) | Confirm a class exists in a specific JAR / version, find the entry path. **Stops here for "what package is this in?" queries.** |
| 10 | **JAR decompilation (edge case only)** | listing entry exists; previous steps returned nothing | Only when no doc source has the answer. Uses the `~/.claude/jar-cache/jar-inspect.sh` helper from `jar-inspection.md`. Never first-line. |

The `--no-web` flag stops the ladder at step 6 (no WebFetch / WebSearch). The `--no-cache` flag skips step 3 reads but still writes new cache entries unless `--refresh` was also passed (which forces a re-fetch and overwrites cache).

## Cache layout (`~/.claude/docs-cache/`)

```
~/.claude/docs-cache/
├── index.json                                  # symbol/topic → file path + source + fetched-at + TTL
├── spring-framework/
│   ├── 7.0.6/
│   │   ├── ServerWebExchange.md
│   │   └── WebFilter.md
│   └── general/
│       └── reactive-streams.md
├── reactor/
│   └── 3.8.4/
│       └── Mono.transform.md
├── kotlinx-coroutines/
│   └── 1.9.0/
│       └── flowOn.md
└── internal/                                   # cached extracts of *this* project's KDoc — keyed by qualified name
    └── com.example.orders.OrderRepository.md
```

Each entry is a small Markdown file with a YAML header:

```yaml
---
source: context7 | webfetch:<url> | kdoc:<path> | jar-listing | jar-decompile
fetched_at: 2026-05-04T10:21:00Z
ttl_days: 30        # 0 = manual-invalidate only (e.g. internal KDoc)
query: "Mono transform operator"
library: reactor
version: 3.8.4
---
<rendered Markdown answer + 1–3 line provenance hint>
```

`index.json` maps `(library, version, query)` → cache file. The skill reads this index to decide hit/miss; the agent surfaces the source provenance in its final answer so the developer can audit.

## Output shape (from the agent)

```markdown
## Doc: <symbol or topic>
Source: <which step on the ladder served the answer>  (cache: hit | miss → write)

### Summary
<2–6 sentences answering the developer's question, with anchors / signatures inline.>

### Key signatures / excerpts
```kotlin
// or whatever language fits — verbatim from the doc
```

### Provenance
- <ladder step> — <path / URL / MCP tool>
- (if cached) — `~/.claude/docs-cache/<path>` (fetched <date>)

### Related
<up to 3 sibling symbols / pages worth reading, each as a one-liner the developer can re-/doc-reveal.>

### What this is missing
<gaps — e.g. "context7 had no entry for this version; web docs were used", "internal KDoc is empty — consider adding /** */ on this class", "JAR-only — no published Javadoc, decompilation was used".>
```

## Why a separate plugin

`komdosh-dev-spring-revealer` answers **"what have we already decided?"** — its sources are decision artefacts (ADRs, specs, commit archaeology, RAG over the project's own writing).

`komdosh-dev-spring-doc-revealer` answers **"what does this *mean* / how do I use it?"** — its sources are reference docs (KDoc, Javadoc, framework manuals, library APIs). Different ladders, different caches, different output shape (the doc one has signatures and anchors; the knowledge one has citations and gap analysis pointing at `/adr-new`).

Splitting them keeps each ladder focused, lets a developer install only the one they need, and avoids tempting the agent to mix "this is the API of `Mono.transform`" with "this is why we picked Reactor over RxJava".

## Dependencies

Required: `komdosh-dev-spring-core` — for `read-service-context` (so the agent knows which package prefix is "internal" vs "external"). The JAR-listing workflow used by ladder steps 9–10 ships **inside this plugin** as [`rules/jar-inspection.md`](rules/jar-inspection.md); no user-global rule is required.

Optional but recommended:
- `mcp__context7__*` — by far the highest-quality library doc source. The plugin is most useful when this is wired up.
- `mcp__ref-context__*` — broader fallback.
- `mcp__codebase-memory-mcp__*` — if the project is indexed, internal KDoc lookups are graph-accurate instead of grep-approximate.

The plugin gracefully degrades: with no MCP and `--no-web`, it still works on in-repo KDoc + `/docs/` + the JAR cache, which covers a surprising fraction of "what does this class do?" queries.

## Constraints

- The agent **never modifies project source code** and never modifies anything outside `~/.claude/docs-cache/`. It is a pure read + cache tool.
- The agent **never auto-runs JAR decompilation** without exhausting the prior steps (steps 1–8). When it does, the output explicitly flags the source as `jar-decompile` so the developer knows the answer didn't come from a doc.
- The cache is **per-version** for libraries — a `reactor 3.8.4` entry never satisfies a `reactor 3.7.x` query. Internal KDoc cache is keyed by qualified name and invalidated on file mtime change.
- The plugin is **standalone**. The JAR listing-first workflow used by ladder steps 9–10 is shipped as [`rules/jar-inspection.md`](rules/jar-inspection.md) below — no dependency on any user-global rules file. The `~/.claude/jar-cache/listings/` directory is opt-in; if absent, steps 9–10 skip gracefully.

@rules/jar-inspection.md
