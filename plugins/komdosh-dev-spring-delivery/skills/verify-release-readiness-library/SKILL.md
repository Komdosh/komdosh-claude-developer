---
name: verify-release-readiness-library
user-invocable: false
description: "Library-track release readiness composite gate. Runs run-verification, scans for internal-API leakage in public packages, runs produce-abi-report and check-publish-config, confirms KDoc on public symbols, deprecation hygiene (replacement + sunset), no -SNAPSHOT deps, license headers present. PASS only when every sub-gate passes. Read-only."
---

# Release Readiness — Library Track

Refuse on a service project. Read-only. **Every sub-gate runs; any FAIL fails the composite.**

| # | Sub-gate | Verdict and remediation |
|---|---|---|
| 1 | Clean working tree | FAIL |
| 2 | `run-verification` green | FAIL routed by category |
| 3 | **No internal API leaking as public** | FAIL with `file:line`. Kotlin is public-by-default, so a declaration in a `*.internal.*` package without the `internal` modifier — or one carrying a `// internal` comment and no modifier — ships as public API and becomes a compatibility obligation nobody intended |
| 4 | ABI report reviewed | Run `produce-abi-report`. **FAIL when it shows breaking deltas and the proposed bump is not major** → bump to major or drop the break. WARN when the validator isn't configured and the report fell back to japicmp |
| 5 | Deprecation hygiene over `last_tag..HEAD` | Every new or changed `@Deprecated` states a **sunset version in its message**, and its level never regresses (ERROR back to WARNING). FAIL → re-run `/deprecate-api`. A missing `replaceWith` is a WARN — whether a successor exists is a judgement call |
| 6 | KDoc on newly-added public symbols (from the ABI report's `added` set) | **WARN, not FAIL** — recommended, not release-blocking |
| 7 | No `-SNAPSHOT` in `runtimeClasspath` | FAIL → `/upgrade <lib>` or pin in the catalog |
| 8 | License headers on added files, **if the project has that convention** | WARN when some are missing; N/A when no convention is detected |
| 9 | `check-publish-config` | Forward its per-check PASS/FAIL/WARN directly |

Statuses and output shape are identical to the service track: the gate table with evidence and remediation, plus JSON (`track`, `composite`, `sub_gates[]`, `first_failure`) that gate 17 consumes.
