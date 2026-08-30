# komdosh-dev-revealer

Retrieval before invention. Two ladders, one discipline: **answer from a real source, cite it, and name the gaps instead of filling them.**

Both halves stop the same failure — inventing an answer that sounds right. `/reveal` prevents re-deciding what the team already decided; `/doc-reveal` prevents recalling an API from training data that has moved on.

## Cheapest source first

Each rung is tried only when the one above it doesn't confidently answer, and **the answer records which rung won**. Decompiling a jar to learn a signature that sits in KDoc three directories away is a real cost; so is a web search for something the project already documents.

`/reveal` runs in **survey** (default), **decision-trace** (one decision and its history), or **gap-find** ("does prior work exist at all — should we write an ADR?").

## Boundary

- **Read-only on project source.** The only thing written anywhere is `/doc-reveal`'s cache under `~/.claude/docs-cache/`.
- **A gap is a result, not a failure.** "No prior work on X — consider an ADR" is the answer. **An invented citation is the failure.**
- Neither half generates knowledge: capturing a decision is `/adr-new`, designing a feature is `/analyze-requirements` or `/implementation-plan`.
- With no MCP configured, both **say which sources were searched and which were skipped and why** — never silently narrowing.

Reach for it before drafting an ADR, before designing into an unfamiliar area, when a pattern's rationale isn't obvious in review, and **whenever you are about to state an API signature, config key, or library behaviour from memory.**

@rules/jar-inspection.md
