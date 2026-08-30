---
description: Surface what the project already knows about a topic — ADRs, specs, plans, code decision comments, commits, and any wired-up knowledge bases — with citations and named gaps.
argument-hint: "<query> [--mode=survey|decision-trace|gap-find] [--scope=adr,specs,code,mcp]"
---

# /reveal

`knowledge-revealer` with the query, mode (default `survey`), and any scope.

Print its output as-is: the synthesis with inline citations, the citation list, the gaps, and the single recommended next step.

**A "no prior work found" answer is a result** — it means greenfield, and it's the signal that an ADR may be worth writing. Don't paper over it.
