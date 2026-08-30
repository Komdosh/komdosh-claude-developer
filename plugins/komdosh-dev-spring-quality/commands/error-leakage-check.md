---
description: Audit every exception handler against the RFC 9457 contract — stack traces, raw exception messages, SQL state, persistence IDs, missing correlation IDs.
---

# /error-leakage-check

`security-auditor --scope=error-leakage`. Narrow slice of `/security-audit`; run after touching error-handling code.

`read-service-context` first; refuse on the library track.

Group findings by severity, each citing `file:line` and the rule from `rules/security-audit.md`. **A missing catch-all `Exception` handler is itself a BLOCKER finding** — uncaught exceptions then surface through the container default, which leaks everything.

Remediation routing: a raw `Map`/`String` body, a leaked `ex.message` or stack trace, or a leaked SQL state is mechanical → `core/cleanuper`. A missing catch-all, or a handler that concatenates its body, needs redesign → `core/backend-implementer`.

Write `docs/security/error-leakage-YYYY-MM-DD.md`.
