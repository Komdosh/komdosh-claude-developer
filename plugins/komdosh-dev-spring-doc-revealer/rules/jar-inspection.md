# JAR Inspection

Listing-first workflow for inspecting JARs. Pre-indexed text listings under `~/.claude/jar-cache/listings/` are **drastically faster** than running `jar tf` every time, especially on repeated lookups against the same Spring Boot / Reactor / Kotlin coroutines distributions. This file defines the workflow `reveal-source-docs` uses for steps 9–10 of its source ladder.

## Cache layout

```
~/.claude/jar-cache/
├── listings/                # one .txt per JAR — "jar tf" output, kept in version-control-free local cache
│   ├── spring-boot-<v>.txt
│   ├── spring-webflux-<v>.txt
│   ├── reactor-core-<v>.txt
│   └── ...
├── jar-inspect.sh           # optional helper: locate JAR by class, optionally decompile
└── README.md                # what's indexed, by version
```

The cache is **per-user** and **opt-in**. Nothing in this plugin requires it to exist; the source ladder probes for it and skips steps 9–10 when it's empty or missing. But once you populate it, the speed-up on repeat queries is large enough that it's worth doing for the JARs you touch every week.

## Mandatory Workflow

Before running `jar tf` on any JAR:

1. **Check if it's already indexed**: `ls ~/.claude/jar-cache/listings/`
2. **If indexed**: use `grep <ClassName> ~/.claude/jar-cache/listings/<name>.txt` — never re-run `jar tf` on it.
3. **If not indexed and you'll touch this JAR more than once**: run `jar tf <jar> > ~/.claude/jar-cache/listings/<name>.txt` **once**, then grep against the listing forever after.
4. **If indexed and the version bumps**: regenerate the listing once for the new version (see "When the version changes" below).

## Recommended JARs to pre-index

These are the libraries `reveal-source-docs` touches most often when answering API queries on a Kotlin / Spring WebFlux service. Pre-indexing them once after a major version bump pays for itself fast.

| Listing (file under `listings/`) | Purpose |
|---|---|
| `spring-boot-<v>.txt` | Core Spring Boot |
| `spring-boot-autoconfigure-<v>.txt` | Auto-configuration classes |
| `spring-webflux-<v>.txt` | WebFlux, WebFilter, ServerWebExchange |
| `spring-context-<v>.txt` | Spring Context, ApplicationContext |
| `spring-security-core-<v>.txt` | Authentication, AuthenticationManager |
| `spring-security-web-<v>.txt` | SecurityWebFilterChain, WebFilter |
| `spring-security-oauth2-resource-server-<v>.txt` | OAuth2 resource server |
| `spring-security-oauth2-jose-<v>.txt` | JWT, JWK |
| `reactor-core-<v>.txt` | Mono, Flux, Context |

Build the table out as you encounter the libraries you care about — there's nothing magic about this list, it's just a starting point. Replace `<v>` with the version you have on disk.

## Fast Class Lookup

```bash
# Which JAR has the class?
grep -l "ReactorContext" ~/.claude/jar-cache/listings/*.txt

# Exact entry path
grep "ReactorContext" ~/.claude/jar-cache/listings/reactor-core-<v>.txt

# Helper script (find + optionally decompile) — only if you've installed jar-inspect.sh
~/.claude/jar-cache/jar-inspect.sh ReactorContext --decompile
```

If you don't have `jar-inspect.sh`, that's fine — the listings alone answer "where does this class live?" for 90 % of queries, and decompilation is the explicit last resort in the source ladder.

## Class Extraction

When decompilation is unavoidable, extract to `/tmp/jar-scratch/<jar-name>/` and **reuse** the scratch dir on subsequent lookups. Never extract to a new unique temp directory each time — that wastes disk and breaks any "I've already decompiled this" optimisation.

## When the Version Changes

When a tracked library version bumps (e.g. `springBoot`, `reactor`, `springSecurity` in `gradle/libs.versions.toml`), regenerate the relevant listing:

```bash
jar tf /path/to/new-version.jar > ~/.claude/jar-cache/listings/<name>-<v>.txt
```

Then update `~/.claude/jar-cache/README.md` (if you keep one) with the new version. The doc-revealer plugin's per-version cache (`~/.claude/docs-cache/<library>/<version>/`) will naturally invalidate, since cache lookups key on the project's pinned version.

## Why this rule ships with the plugin

`reveal-source-docs` step 9–10 invokes this workflow. Shipping it inside the plugin makes installations standalone — every user of the marketplace gets the same listing-first behaviour without needing to copy a personal global rule into their `~/.claude/rules/`.
