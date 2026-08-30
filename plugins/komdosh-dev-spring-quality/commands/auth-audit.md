---
description: Build the route↔SecurityWebFilterChain coverage matrix for every handler — unauthenticated routes, unrationalized permit-alls, and shadowed rules.
argument-hint: "[--module=<glob>]"
---

# /auth-audit

`security-auditor --scope=auth`. The narrow slice of `/security-audit` — use it after adding an endpoint group, when the full audit is overkill.

`read-service-context` first; refuse on the library track.

**Print the complete matrix, not just the findings** — every handler, its class (authenticated / permit-all-by-rule / **UNMATCHED** / **SHADOWED**), and the filter rule `file:line` that decided it, ending with the totals. The unmatched rows are the endpoints nobody knows are open, and they only stand out against the full list.

Per BLOCKER, give the exact remediation prompt for `core/backend-implementer` — which rule, in which file, **placed before the terminal matcher**. Per unrationalized `permitAll`, offer the three real options: annotate with `// PUBLIC: <rationale>`, open an ADR, or tighten the rule.

Write `docs/security/auth-audit-YYYY-MM-DD.md`.
