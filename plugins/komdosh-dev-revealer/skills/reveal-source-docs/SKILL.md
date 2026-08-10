---
name: reveal-source-docs
user-invocable: false
description: Walks a fixed source-documentation ladder from cheapest to most expensive — in-repo KDoc/Javadoc → project /docs/ → ~/.claude/docs-cache/ → MCP (codebase-memory, context7, ref-context) → canonical web URLs via WebFetch → WebSearch+WebFetch → pre-indexed JAR listings → JAR decompilation as edge-case-only last resort. Stops at the first source that confidently answers, normalises the snippet, writes a cache entry, and returns a JSON descriptor (winning_source, snippets, provenance, related, gaps). Read-only on project files; only writes under ~/.claude/docs-cache/. Use when an agent needs to find documentation for a symbol, topic, library, or framework without re-explaining from training data.
---

# Reveal Source Docs

## When to Use

Run this skill whenever an agent needs to find **documentation about a symbol, library, framework, or architectural pattern** — i.e. the meaning / API / usage of code, not the project's decision history. Examples:

- "What does `OrderRepository.fetchPending` do?" — internal KDoc.
- "What's the signature of `Mono.transform`?" — library doc.
- "How does `WebFilter` ordering work in Spring 7?" — framework reference.
- "What's the architecture of the `orders` module?" — project `/docs/`.
- "Where does `org.jooq.DSLContext` live?" — pre-indexed JAR listing.

Read-only on project source; only writes under `~/.claude/docs-cache/`.

## Inputs

- `query` (required) — symbol, topic, library name, or `library#anchor`.
- `kind` (optional, default `auto`) — `auto | internal | library | architecture`.
- `depth` (optional, default `summary`) — `summary | full`.
- `no_web` (optional, default false) — stop the ladder at step 6 (no WebFetch / WebSearch).
- `no_cache` (optional, default false) — bypass cache *read*; still write fresh entries.
- `refresh` (optional, default false) — force re-fetch and overwrite the cache entry.
- `max_snippets` (optional, default 3 at `summary`, 8 at `full`) — cap the snippets in the output.

## Output

A JSON descriptor (the calling agent reads this; the agent does the human-facing rendering):

```json
{
  "query": "Mono.transform",
  "classified_kind": "library",
  "winning_source": "mcp:context7",
  "cache_status": "miss-write",
  "cache_path": "~/.claude/docs-cache/reactor/3.8.4/Mono.transform.md",
  "snippets": [
    {
      "lang": "kotlin",
      "anchor": "Mono.transform",
      "body": "fun <V> transform(transformer: Function<in Mono<T>, out Publisher<V>>): Mono<V>",
      "source_ref": "context7://reactor/3.8.4#Mono.transform"
    }
  ],
  "provenance": [
    {
      "step": 5,
      "label": "mcp:context7",
      "ref": "library-id=/reactor/reactor-core?v=3.8.4 query=\"Mono transform operator\"",
      "fetched_at": "2026-05-04T10:21:00Z"
    }
  ],
  "related": ["Mono.flatMap", "Mono.transformDeferred", "Flux.transform"],
  "gaps": [
    "context7 returned the 3.8.x family doc; verify it matches the project's pinned reactor version."
  ]
}
```

If every step misses, return `winning_source: null` and populate `gaps` with what was tried + what the developer can do.

## The ladder (run in order, stop at the first confident hit)

The skill **walks the ladder in order**. A "confident hit" means: a snippet that actually answers the developer's query, not just "the symbol exists". For `summary` depth, one solid signature + 1–2 lines of explanatory prose is enough. For `full`, accumulate snippets until you've covered the requested anchor or the source is exhausted.

If `kind` is set, you may **fast-forward the entry point** to the appropriate step — but every step after the entry still runs in order on miss.

| `kind` | Entry step |
|---|---|
| `internal` | 1 |
| `architecture` | 2 |
| `library` | 3 |
| `auto` | classify (see Step 0), then map |

### Step 0 — Classify (only if `kind=auto`)

- If `query` looks like a fully-qualified name and starts with the service's base package (read from `read-service-context`) → `internal`.
- Else if it contains "architecture", "module", "package", "boundary", "pattern in this codebase" → `architecture`.
- Else if it matches a known library name or coordinate (Spring / Reactor / kotlinx.coroutines / jOOQ / Liquibase / Micrometer / OTel / Jackson / kotlinx.serialization / Spring Security / Spring Boot / R2DBC / etc.) → `library`.
- Default → `library`.

Record the classification in `classified_kind`.

### Step 1 — In-repo KDoc / Javadoc

```bash
# locate the file containing the symbol
grep -rn --include='*.kt' --include='*.java' "\b<symbol>\b" .
# read the /** ... */ block immediately above the declaration
```

For multi-word topics (e.g. "WebFilter ordering"), this step usually misses — that's expected. Move on.

For internal qualified names, prefer the IDE index when available (`mcp__intellij-index__ide_find_class` then read the file around the line); fall back to grep.

Confident hit if a `/** ... */` block of ≥3 lines is attached to the symbol declaration. Empty / one-line KDoc → record as a gap and continue down the ladder.

### Step 2 — Project `/docs/`

```bash
# search architectural docs (excluding the dirs scanned by the knowledge-revealer)
grep -rilE '<query-keywords>' docs/architecture* docs/<module>* README.md \
  packages/*/package-info.kt 2>/dev/null
```

Confident hit if the doc has a heading or paragraph about the query. Capture file + heading + 5-10 line excerpt.

### Step 3 — `~/.claude/docs-cache/`

Read `~/.claude/docs-cache/index.json`. Look up `(library, version, query)`:

- For `library` queries, derive `library` from the symbol prefix or context (`Mono.transform` → `reactor`; `flowOn` → `kotlinx-coroutines`; `WebFilter` + Spring → `spring-framework`). Derive `version` from the project's `gradle/libs.versions.toml` or `pom.xml`.
- For `internal` queries, the cache key is the qualified name; invalidate on file mtime change (compare cached `fetched_at` with `git log -1 --format=%ct -- <file>`).

Honour TTL (default 30 days for libraries; 0 / manual-invalidate for internal). On `--refresh`, treat all hits as misses.

Confident hit = a non-stale cache entry exists. Read it and use as the snippet source. `cache_status = "hit"`. Skip the rest of the ladder.

If `no_cache=true`, skip the **read** but still allow downstream steps to write a fresh entry.

### Step 4 — MCP `mcp__codebase-memory-mcp__*`

Probe `mcp__codebase-memory-mcp__index_status`. If indexed:

- For internal symbols: `mcp__codebase-memory-mcp__search_graph` with `name_pattern=<symbol>` to find the qualified name; then `mcp__codebase-memory-mcp__get_code_snippet` to read the source + nearby doc comment.
- For architecture queries: `mcp__codebase-memory-mcp__get_architecture` to retrieve the project structure.

Confident hit = the snippet contains a doc comment **or** the architecture aspect requested.

### Step 5 — MCP `mcp__context7__*`

Two-call protocol — never skip the resolve step:

1. `mcp__context7__resolve-library-id` with the library name + the user's full question. Pick the best match (exact name, code snippet count, version match — prefer one whose version segment matches the project's pinned version).
2. `mcp__context7__query-docs` with the resolved id and the **full** question (not single keywords). Single-keyword queries return shallow page lists; the full question gives the server enough signal to extract the right section.

Best for libraries with public reference docs (Spring, Reactor, kotlinx.coroutines, kotlinx.serialization, jOOQ, Micrometer, OTel, Jackson, ...).

Confident hit = at least one returned doc snippet that names the symbol or directly answers the topic. Record the resolved library-id and the version the doc applies to in provenance.

### Step 6 — MCP `mcp__ref-context__*`

`mcp__ref-context__ref_search_documentation` with the query. If a result has a clear URL, optionally `mcp__ref-context__ref_read_url` to fetch the page body.

Use as the next-best general docs search when context7 has no entry.

### Step 7 — WebFetch on canonical URLs

If `no_web=true`, skip to step 9.

Build candidate URLs from the library and the symbol. The agent must already know the project's pinned version (from `libs.versions.toml`) — use it in the URL.

| Library / framework | URL template |
|---|---|
| Spring Framework | `https://docs.spring.io/spring-framework/reference/<topic>.html` and `https://docs.spring.io/spring-framework/docs/<v>/javadoc-api/<class-path>.html` |
| Spring Boot | `https://docs.spring.io/spring-boot/<v>/reference/<topic>.html` |
| Spring Security | `https://docs.spring.io/spring-security/reference/<v>/<topic>.html` |
| Reactor | `https://projectreactor.io/docs/core/<v>/api/reactor/core/publisher/<class>.html` and `https://projectreactor.io/docs/core/<v>/reference/index.html` |
| Kotlin / kotlinx | `https://kotlinlang.org/api/kotlinx.coroutines/<package>/<symbol>.html` and `https://kotlinlang.org/api/core/<package>/<symbol>.html` |
| Generic Maven artefact | `https://javadoc.io/doc/<group>/<artifact>/<v>/<class-path>.html` (and `/index.html` for the package list) |
| Open source on GitHub | `https://github.com/<org>/<repo>#readme`, `https://github.com/<org>/<repo>/wiki/<page>`, `https://raw.githubusercontent.com/<org>/<repo>/<ref>/README.md` |

Try at most 3 candidate URLs in priority order. WebFetch each; if the body contains the symbol or a section heading matching the query, it's a hit.

Confident hit = the fetched HTML contains the symbol declaration or a topical section that answers the query.

### Step 8 — WebSearch fallback

`WebSearch` for `<query> <library> documentation`. Pick the top result that is a known docs host (`docs.*.org`, `*.io/doc`, `*.github.io`, `*.readthedocs.io`, `kotlinlang.org`, `javadoc.io`, `projectreactor.io`, `docs.spring.io`, repository wikis). WebFetch the URL.

Confident hit = same criteria as step 7.

If the only matching result is a Stack Overflow or blog post, do NOT use it — those are not source docs. Drop to step 9.

### Step 9 — Pre-indexed JAR listings

Per the plugin-shipped `rules/jar-inspection.md` (loaded into every session via this plugin's CLAUDE.md). The cache directory `~/.claude/jar-cache/listings/` is opt-in — populate it once for the JARs you touch repeatedly; the skill works fine when it's empty.

First, **probe**:

```bash
[ -d ~/.claude/jar-cache/listings ] && ls ~/.claude/jar-cache/listings/*.txt 2>/dev/null | head -1
```

If the directory does not exist, contains no listings, or the helper script is absent, **skip steps 9 and 10 entirely** — record `gap: "no JAR listings configured at ~/.claude/jar-cache/listings/; steps 9–10 skipped"` and return.

If listings are present:

```bash
grep '<ClassName>' ~/.claude/jar-cache/listings/*.txt            # find the JAR + entry path
[ -x ~/.claude/jar-cache/jar-inspect.sh ] && \
  ~/.claude/jar-cache/jar-inspect.sh <ClassName>                 # locate the JAR (only if the helper exists)
```

Never run `jar tf` on a pre-indexed JAR — use the listing. See `rules/jar-inspection.md` for how to add a new listing when a library version bumps.

For "where does this class live?" queries, this is often a **terminal answer** (it's a question about packaging, not API meaning). Stop here for those.

For "what does it do?" queries, this is a *signal* (the class exists, here's its location), not an answer — continue to step 10 only if the developer truly needs the API and no doc source had it.

### Step 10 — JAR decompilation (edge case only)

Run *only* if:
- Steps 1–8 returned no confident hit, AND
- The developer's query is about API meaning / signature (not packaging), AND
- The JAR cache and `jar-inspect.sh` helper described in this plugin's `rules/jar-inspection.md` exist (otherwise skip with a gap, as in step 9).

```bash
~/.claude/jar-cache/jar-inspect.sh <ClassName> --decompile
```

Extract to `/tmp/jar-scratch/<jar-name>/` (per the global rule — reuse, don't pick a new temp dir each time). Read the decompiled source. Capture:
- The class signature.
- Public method signatures.
- Any retained `/** */` (rare in shipped JARs).

Mark the snippet `source_ref` as `jar-decompile:<jar>:<entry>`. Add a gap explicitly: "no published doc — answer is bytecode-derived, treat with care".

## Cache write protocol

After a confident hit at any step **other than step 3 (cache hit)**:

1. Compute the cache path:
   - `library`: `~/.claude/docs-cache/<library>/<version>/<symbol-or-slug>.md`
   - `internal`: `~/.claude/docs-cache/internal/<qualified-name>.md`
   - `architecture`: `~/.claude/docs-cache/internal/<module-or-slug>.md`
2. Build the file body:

```markdown
---
source: <ladder step label>
fetched_at: <ISO-8601 UTC>
ttl_days: <30 for libraries, 7 for web-search-derived URLs, 0 for internal>
query: "<original query>"
library: <name or "internal">
version: <pinned version or empty for internal>
provenance:
  - step: <N>
    ref: <path|url|tool>
---

# <Symbol or topic>

<2–6 sentence summary derived from the snippets>

## Signatures / excerpts

```<lang>
<verbatim>
```

## Related
- <symbol-1>
- <symbol-2>

## Notes
<any gaps or version caveats>
```

3. Update `~/.claude/docs-cache/index.json`:

```json
{
  "<library>:<version>:<query-slug>": {
    "path": "<library>/<version>/<symbol>.md",
    "source": "<ladder step label>",
    "fetched_at": "<ISO-8601>",
    "ttl_days": 30
  }
}
```

If `index.json` does not exist, create it with `mkdir -p` first. Never overwrite the index — read, merge, write.

If `cache_status: hit` (step 3 served the answer), do NOT rewrite — the cache is authoritative until TTL or `--refresh`.

## Steps

- [ ] **Step 1: Classify the query** (Step 0 above) — record `classified_kind`.

- [ ] **Step 2: Determine entry step** — from the `kind`-to-step table.

- [ ] **Step 3: Walk the ladder in order from the entry step** — record every attempted step under `provenance` (with success/miss). Stop at the first **confident hit**, EXCEPT:
  - If the hit is at step 9 and the query is about API meaning (not packaging), continue to step 10.
  - If `no_web=true` and the entry is past step 6, never run steps 7 or 8.

- [ ] **Step 4: Build the snippet list**
  - At `depth=summary`: keep up to 3 of the most-relevant snippets (signature first).
  - At `depth=full`: keep up to 8, grouped by anchor.
  - Trim each snippet to the smallest body that grounds the answer — never return a whole HTML page; extract the relevant `<pre>` / `<code>` / `<section>` content.

- [ ] **Step 5: Build the related list**
  - Sibling symbols on the same page (HTML doc → headings near the matched anchor).
  - Sibling members on the same class (Javadoc method index).
  - Cap at 3 (or `max_snippets / 2`, rounded down). Drop self-references.

- [ ] **Step 6: Build the gaps list**
  - Internal KDoc was empty → "internal KDoc on `<symbol>` is empty; consider adding /** */".
  - Library doc version differs from project pinned version → "doc applies to <doc-version>; project pins <pinned>".
  - Source was step 7/8 (web) → "no MCP doc source was wired up; consider installing context7 / ref-context".
  - Source was step 10 (JAR decompile) → "no published doc — answer is bytecode-derived".
  - All steps missed → list every step tried + a one-line reason per skip.

- [ ] **Step 7: Write the cache entry** (if `cache_status` is `miss-write` and `winning_source` is non-null).

- [ ] **Step 8: Return the JSON descriptor** per the Output format above.

## Notes

- This skill is the **only** filesystem-writer in this plugin, and it only writes under `~/.claude/docs-cache/`. Never write into the project workspace, never modify `~/.claude/jar-cache/listings/`, never modify any rules file.
- Keep snippets **verbatim**. Never paraphrase a doc snippet — paraphrasing reintroduces the "made up the API from training data" failure mode this skill exists to prevent. The agent above paraphrases for the Summary, but the snippet body stays verbatim.
- Per the plugin-shipped `rules/jar-inspection.md` (loaded via the plugin's CLAUDE.md): when listings exist at `~/.claude/jar-cache/listings/`, `jar tf` is forbidden on them — use `grep` against the `.txt` files. When listings are absent, steps 9–10 skip with a recorded gap.
- For `context7`: always start a lookup with `resolve-library-id` and pass the **full** user question (not single keywords) to `query-docs` (step 5 enforces this).
- TTL guidance:
  - Library reference docs (context7, canonical URLs): **30 days** — these change rarely once a version is published; the cache is invalidated naturally on a version bump.
  - Web-search-derived URLs (step 8): **7 days** — search rankings shift; treat with shorter trust.
  - Internal KDoc: **0 (no TTL)** — invalidate on file mtime change. Compare cached `fetched_at` to `git log -1 --format=%ct -- <file>` on every read.
- The cache is **never** authoritative for `--refresh`. `--refresh` always re-walks the ladder from the entry step.
- For very large repos, scope the step-1 grep to the directories most likely to contain the symbol (`grep -rn --include='*.kt' "\b<symbol>\b" application/ domain/ adapters/`), not the whole tree. The `read-service-context` skill provides the module list.
