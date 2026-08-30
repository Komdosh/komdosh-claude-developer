---
description: Find real documentation for a symbol, topic, or library — cheapest source first, cached, with provenance and gaps. Never answers from memory.
argument-hint: "<symbol|topic|library> [--kind=] [--depth=summary|full] [--no-web] [--refresh]"
---

# /doc-reveal

`doc-revealer` with the query and any of `--kind` (`auto|internal|library|architecture`), `--depth`, `--no-web`, `--no-cache`, `--refresh`.

Print its output as-is — summary, verbatim signatures, provenance, related symbols, and gaps.

**Every signature shown is verbatim from a fetched source.** If nothing was found, that is the answer, together with the concrete next step.

On a first lookup of something you'll return to, `--depth=full` makes the cached entry rich enough that follow-ups need no re-fetch.
