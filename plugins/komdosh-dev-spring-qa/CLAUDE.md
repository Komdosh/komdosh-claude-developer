# CLAUDE.md — komdosh-dev-spring-qa

This plugin adds an end-to-end QA artifact suite on top of `komdosh-dev-spring-core`.

## What it adds

Three independent commands, each backed by its own narrowly-scoped agent. All three share a single discovery skill so endpoints, DTOs, sample values, and the auth scheme are read once and consistently across artifacts.

| Command | Agent | Output |
|---|---|---|
| [`/qa-plan`](commands/qa-plan.md) | [`qa-plan-writer`](agents/qa-plan-writer.md) | `docs/qa/manual-validation-plan.md` — markdown checklist (prereqs · smoke journey · per-resource happy + error · observability · cross-cutting · teardown). Re-runs preserve checked boxes by step id. |
| [`/qa-postman`](commands/qa-postman.md) | [`qa-postman-writer`](agents/qa-postman-writer.md) | `docs/qa/postman/<service>.postman_collection.json` + per-environment files (local · dev · staging). v2.1 schema, `pm.test` assertions on status + content-type + problem+json shape, chained variables (POST → GET /:id), `_errors/` subfolder per resource. Newman-runnable. |
| [`/qa-console`](commands/qa-console.md) | [`qa-console-writer`](agents/qa-console-writer.md) | `docs/qa/qa-console.html` — single self-contained file (inline CSS + vanilla JS, no CDN, no build step). Sidebar of endpoints, auto-generated forms from your DTOs, env switcher, persistent token field, request history, "copy as curl". Opens from `file://`. |

Shared skill:

- [`discover-api-surface`](skills/discover-api-surface/SKILL.md) — resolves your service's HTTP surface into a normalised JSON IR. Tries OpenAPI file, then Springdoc runtime if hinted, then static controller parse. Run **once per session** when generating multiple QA artifacts back-to-back.

This plugin ships **no hooks** by design. Staleness of QA artifacts relative to controller mtimes is surfaced by core's `service-readiness-auditor` when it runs — not on every edit.

## Dependencies

This plugin requires `komdosh-dev-spring-core` to be installed in the same project. Each command begins with `read-service-context` (a core skill). The `service-readiness-auditor` agent (in core) warns when these QA artifacts are missing or stale relative to controller mtimes (warn-level only — never a BLOCKER).
