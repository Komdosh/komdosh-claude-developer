---
name: module-boundary-check
allowed-tools: Grep, Glob, Read
description: Grep-based fast preflight that imports across modules respect the hexagonal arrows from rules/hexagonal.md. Catches `domain/` importing Spring/jOOQ/Kafka/Jackson, and `adapters/inbound` importing `adapters/outbound`, in seconds. Cheaper than running ArchUnit. Run after editing any file under domain/, application/, or adapters/.
---

# Module Boundary Check

Enforces `rules/hexagonal.md` and `rules/domain-purity.md`. Run after editing anything under `domain/`, `application/`, `adapters/`, or `boot/`, **before** `run-verification`. **The ArchUnit suite in `tests/architecture/` remains the authoritative check** — this is the fast per-line preflight.

Only `^import` lines are matched, so a fully-qualified use inside a body is not caught here; detekt's `ForbiddenImport` is the complementary check.

## 1. Scope

Caller's touched files, or the merge-base diff filtered to the module roots:

```bash
git merge-base HEAD origin/main 2>/dev/null \
  | xargs -I{} git diff --name-only {}..HEAD -- '*.kt' \
  | grep -E '^(domain|application|adapters/(inbound|outbound)|boot)/' || true
```

## 2. Checks

| Rule | Module | Flag |
|---|---|---|
| DP-1 | `domain/` | `^import (org\.springframework\|org\.jooq\|org\.apache\.kafka\|io\.r2dbc\|com\.fasterxml\.jackson\|jakarta\.persistence)\.` |
| DP-2 | `application/` | same set, **minus** `org.springframework.transaction` — tolerated only as a fallback where `TransactionalOperator` isn't available (`rules/persistence.md`) |
| HX-1 | `adapters/inbound/` | `^import .*\.adapters\.outbound\.` — go through `application/ports/` |
| HX-2 | `adapters/outbound/` | `^import .*\.adapters\.inbound\.` — that direction is a feedback loop |
| HX-3 | `domain/` | `^import .*\.(application\|adapters\|boot)\.` — nothing flows inward |
| HX-4 | `application/` | `^import .*\.(adapters\|boot)\.` — use cases don't depend on implementations |

In a multi-service repo, scope the greps to the current service root.

## 3. Report

`[RULE] BLOCKER file:line` + the offending import + the one-line reason. Then `Module boundary: CLEAN (N files)` or the count.

**Never auto-fix.** These fixes are structural — introducing a port, moving a class. Rewriting an import to dodge the rule is the failure mode this exists to prevent. Escalate to `backend-implementer` and confirm with `./gradlew :tests:architecture:test`.
