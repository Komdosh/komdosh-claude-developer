---
name: module-boundary-check
allowed-tools: Grep, Glob, Read
description: Grep-based fast preflight that imports across modules respect the hexagonal arrows from rules/hexagonal.md. Catches `domain/` importing Spring/jOOQ/Kafka/Jackson, and `adapters/inbound` importing `adapters/outbound`, in seconds. Cheaper than running ArchUnit. Run after editing any file under domain/, application/, or adapters/.
---

# Module Boundary Check

## When to Use

Run after editing any Kotlin file under:

- `domain/`
- `application/`
- `adapters/inbound/`
- `adapters/outbound/`
- `boot/`

**Before** `run-verification` — this skill takes a few seconds and gives you per-line errors. The full ArchUnit suite under `tests/architecture/` is the source of truth, but it runs in tens of seconds and gives less helpful messages.

This skill enforces [`rules/hexagonal.md`](../../rules/hexagonal.md) (dependency direction) and [`rules/domain-purity.md`](../../rules/domain-purity.md) (banned imports in `domain/` / `application/`).

## Output

Per violation:

```
[<rule>] BLOCKER <file>:<line>
  import <offending-package>
  Why: <one-line rationale>
```

Plus the summary line:

```
Module boundary: <CLEAN | N violations>
```

## Steps

- [ ] **Step 1: Determine scope**

If the calling agent supplied a list of touched files, use those (filtered to `*.kt` under the four module dirs). Otherwise, scan files modified relative to the merge base:

```bash
git merge-base HEAD origin/main 2>/dev/null \
  | xargs -I{} git diff --name-only {}..HEAD -- '*.kt' \
  | grep -E '^(domain|application|adapters/(inbound|outbound)|boot)/'
```

- [ ] **Step 2: Apply per-module banned-import checks**

```bash
files_in() { printf '%s\n' "${@}" | grep -E "^$1/" || true; }

# [DP-1] domain/ — no framework imports at all
for f in $(files_in domain "${touched[@]}"); do
  grep -nE '^import (org\.springframework|org\.jooq|org\.apache\.kafka|io\.r2dbc|com\.fasterxml\.jackson|jakarta\.persistence)\.' "$f"
done

# [DP-2] application/ — same banned imports as domain (one tolerated exception: org.springframework.transaction)
for f in $(files_in application "${touched[@]}"); do
  grep -nE '^import (org\.springframework|org\.jooq|org\.apache\.kafka|io\.r2dbc|com\.fasterxml\.jackson|jakarta\.persistence)\.' "$f" \
    | grep -v 'org\.springframework\.transaction'
done

# [HX-1] adapters/inbound/ — no imports from adapters.outbound
for f in $(files_in adapters/inbound "${touched[@]}"); do
  grep -nE '^import .*\.adapters\.outbound\.' "$f"
done

# [HX-2] adapters/outbound/ — no imports from adapters.inbound
for f in $(files_in adapters/outbound "${touched[@]}"); do
  grep -nE '^import .*\.adapters\.inbound\.' "$f"
done

# [HX-3] domain/ — no imports from application/, adapters/, boot/
for f in $(files_in domain "${touched[@]}"); do
  grep -nE '^import .*\.(application|adapters|boot)\.' "$f" \
    | grep -v "^.*\.application\.ports\."   # domain → application.ports is allowed in some shapes; review case-by-case
done

# [HX-4] application/ — no imports from adapters/, boot/
for f in $(files_in application "${touched[@]}"); do
  grep -nE '^import .*\.(adapters|boot)\.' "$f"
done
```

- [ ] **Step 3: Map each rule to a one-line rationale**

| Rule | Rationale (used in the report) |
|---|---|
| DP-1 | `domain/` must have zero framework imports — see `rules/domain-purity.md` |
| DP-2 | `application/` may not import jOOQ/Kafka/Jackson; only `org.springframework.transaction` is tolerated, and only as a fallback when `TransactionalOperator` is not available |
| HX-1 | `adapters/inbound` must not call `adapters/outbound` directly — go through `application/ports/` |
| HX-2 | `adapters/outbound` must not call `adapters/inbound` directly — that would be a feedback loop |
| HX-3 | `domain/` is the inner core; nothing outside may flow inward |
| HX-4 | `application/` orchestrates use cases; it must not depend on adapter implementations |

- [ ] **Step 4: Report**

If clean:

```
Module boundary: CLEAN (<N> files scanned).
```

Else, one line per violation per the Output format, then:

```
Module boundary: <K> violations.
Hand back to backend-implementer or cleanuper to fix.
The full ArchUnit suite (tests/architecture/) is the authoritative check —
run it via `./gradlew :tests:architecture:test` after fixing.
```

- [ ] **Step 5: Do not auto-fix**

Architectural fixes are usually structural (introducing a port, moving a class). Do not let any agent silently rewrite imports to bypass the rule — escalate to `backend-implementer` instead.

## Notes

- The grep is intentionally conservative: it only flags `^import` lines, so qualified-name uses inside the source body (rare and usually wrong anyway) are not caught here. Detekt's `ForbiddenImport` rule is a complementary check.
- For multi-service repos, scope the grep to the current service's directory if the layout has more than one root.
- The "tolerated exception" for `org.springframework.transaction` in DP-2 reflects real codebases. If your service uses `TransactionalOperator` exclusively (the recommended pattern from [`rules/persistence.md`](../../rules/persistence.md)), remove that exception in your local fork.
