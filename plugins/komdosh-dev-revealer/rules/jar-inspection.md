# JAR Inspection

Listing-first. Pre-indexed `jar tf` output under `~/.claude/jar-cache/listings/` answers "which jar holds this class" far faster than re-running `jar tf`, and repeat lookups against the same Spring/Reactor distributions are the common case. `reveal-source-docs` uses this for the last rungs of its ladder.

The cache is **per-user and opt-in** — nothing requires it, and the ladder skips these rungs when it is missing.

## Workflow — before any `jar tf`

1. `ls ~/.claude/jar-cache/listings/` to see what's indexed.
2. Indexed → `grep <ClassName> ~/.claude/jar-cache/listings/<name>.txt`. **Never re-run `jar tf` on an indexed jar.**
3. Not indexed, and you'll touch it more than once → `jar tf <jar> > ~/.claude/jar-cache/listings/<name>-<v>.txt` **once**, then grep forever after.
4. Version bumped → regenerate that one listing. The per-version `~/.claude/docs-cache/<library>/<version>/` invalidates on its own, since lookups key on the project's pinned version.

`grep -l "<ClassName>" ~/.claude/jar-cache/listings/*.txt` answers "which jar" across the whole cache.

Worth pre-indexing on a Kotlin/WebFlux service: `spring-boot`, `spring-boot-autoconfigure`, `spring-webflux`, `spring-context`, `spring-security-{core,web}`, `spring-security-oauth2-{resource-server,jose}`, `reactor-core` — extend as you go; there is nothing special about that list.

## Decompilation is the last resort

When it is unavoidable, extract to `/tmp/jar-scratch/<jar-name>/` and **reuse that directory** on later lookups. A fresh unique temp dir each time wastes disk and defeats any "already decompiled this" shortcut.

The listings alone answer "where does this class live" for the large majority of queries.
