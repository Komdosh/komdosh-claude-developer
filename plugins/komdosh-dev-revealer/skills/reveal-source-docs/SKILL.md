---
name: reveal-source-docs
user-invocable: false
description: Walks a fixed source-documentation ladder from cheapest to most expensive — in-repo KDoc/Javadoc → project /docs/ → ~/.claude/docs-cache/ → MCP (codebase-memory, context7, ref-context) → canonical web URLs via WebFetch → WebSearch+WebFetch → pre-indexed JAR listings → JAR decompilation as edge-case-only last resort. Stops at the first source that confidently answers, normalises the snippet, writes a cache entry, and returns a JSON descriptor (winning_source, snippets, provenance, related, gaps). Read-only on project files; only writes under ~/.claude/docs-cache/. Use when an agent needs to find documentation for a symbol, topic, library, or framework without re-explaining from training data.
---

# Reveal Source Docs

Finds documentation for a symbol, library, framework, or pattern — the *meaning* of code, not the project's decision history. Read-only on project source; writes only under `~/.claude/docs-cache/`.

Inputs: `query` · `kind` (`auto|internal|library|architecture`) · `depth` (`summary|full`) · `no_web` · `no_cache` (skip cache *reads*, still write) · `refresh` (force re-fetch) · `max_snippets`.

Returns JSON: `query`, `classified_kind`, `winning_source`, `cache_status`, `cache_path`, `snippets[]` (each with lang, anchor, body, `source_ref`), `provenance[]` (step, label, ref, `fetched_at`), `related[]`, `gaps[]`. **Every step miss returns `winning_source: null` with `gaps` naming what was tried** — never an unsourced answer.

## Walking the ladder

Run in order and stop at the first **confident hit** — a snippet that answers the question, not merely proof the symbol exists. At `summary`, one solid signature plus a line or two of prose; at `full`, accumulate until the anchor is covered.

`kind` fast-forwards the *entry* step (`internal`→1, `architecture`→2, `library`→3); every later step still runs in order on a miss.

**Step 0 — classify** (only when `kind=auto`): a fully-qualified name under the service's base package → `internal`; wording about architecture/modules/boundaries → `architecture`; a known library name → `library`; default `library`.

**1. In-repo KDoc/Javadoc.** Locate the declaration (IDE index when available, else grep) and read the `/** */` above it. **A one-line or empty KDoc is a gap, not a hit** — record it and continue. Multi-word topics usually miss here; that's expected.

**2. Project `/docs/`.** Architectural docs and READMEs. Hit = a heading or paragraph on the query; capture file, heading, and a short excerpt.

**3. `~/.claude/docs-cache/`.** Key on `(library, version, query)` — derive the library from the symbol prefix (`Mono.transform` → reactor, `flowOn` → kotlinx-coroutines) and the version from the project's pinned catalog. Internal entries key on the qualified name and **invalidate on the file's git mtime**. TTL 30 days for libraries, manual for internal. A non-stale hit ends the ladder; `refresh` treats every hit as a miss.

**4. `codebase-memory` MCP.** Check `index_status` first. `search_graph` → `get_code_snippet` for internal symbols; `get_architecture` for structure. Hit = the snippet carries a doc comment, or the requested architectural aspect.

**5. `context7` MCP — two calls, never skip the resolve.** `resolve-library-id` with the library name *and* the user's full question, preferring a match whose version segment matches the project's pin; then `query-docs` with the resolved id and **the full question**. A single keyword returns shallow page lists; the whole question gives the server enough signal to extract the right section. Record the resolved id and the doc's version in provenance.

**6. `ref-context` MCP.** `ref_search_documentation`, then `ref_read_url` on a clear result. The general fallback when context7 has no entry.

**7. WebFetch on canonical URLs** (skipped when `no_web`). Build at most three candidates using the project's **pinned version**:

| | |
|---|---|
| Spring Framework / Boot / Security | `docs.spring.io/<project>/…/reference/<topic>.html`, or the versioned `javadoc-api` path |
| Reactor | `projectreactor.io/docs/core/<v>/api/…` |
| Kotlin / kotlinx | `kotlinlang.org/api/…` |
| Any Maven artifact | `javadoc.io/doc/<group>/<artifact>/<v>/…` |
| OSS on GitHub | the raw README, or the wiki page |

Hit = the fetched body contains the declaration or a topical section answering the query.

**8. WebSearch fallback.** Take the top result **only from a known docs host** (`docs.*.org`, `*.io/doc`, `*.github.io`, `readthedocs`, `kotlinlang.org`, `javadoc.io`, `projectreactor.io`), then WebFetch it. **A Stack Overflow answer or a blog post is not a source doc — drop to step 9 instead of using one.**

**9. Pre-indexed JAR listings** (`rules/jar-inspection.md`). Probe `~/.claude/jar-cache/listings/` first; empty or absent → record the gap and **skip 9 and 10 entirely**. `grep '<ClassName>' …/listings/*.txt` locates the jar and entry path. Never `jar tf` an indexed jar.

For **"where does this class live"** this is a terminal answer — stop. For "what does it do" it is only a signal.

**10. Decompilation — edge case only.** Requires all of: steps 1–8 missed, the question is about API meaning rather than packaging, and the jar cache exists. Extract to the shared `/tmp/jar-scratch/<jar>/`, capture the class and public method signatures, mark `source_ref` as `jar-decompile:…`, and **always add the gap: "no published doc — bytecode-derived, treat with care."**

## Cache write

After a confident hit at any step **other than 3**, write `~/.claude/docs-cache/<library>/<version>/<slug>.md` (internal and architecture go under `internal/`) with frontmatter carrying `source`, `fetched_at`, `ttl_days` (30 libraries · 7 web-search-derived · 0 internal), `query`, `library`, `version`, and `provenance`; then a short summary, the verbatim signatures, related symbols, and any caveats.

**Merge into `~/.claude/docs-cache/index.json`, never overwrite it.** On a step-3 hit, write nothing — the cache is authoritative until TTL or `refresh`.
