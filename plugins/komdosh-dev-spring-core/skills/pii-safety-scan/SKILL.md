---
name: pii-safety-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*)
description: Scans Kotlin/Spring source for personal-data (PII) exposure on the data-in-motion surface — raw PII in log and trace statements, PII in span attributes / metric tags / MDC, PII value classes without a redacting toString(), unmasked PII in response DTOs, PII in event and Avro payloads, PII in error-response bodies, and subject-rights reachability. Runs at depth=fast (four families, seconds, for the dev loop) or depth=audit (all seven families, for a classified security report). Read-only; reports file:line and the PII field, and never prints the personal-data value itself. Use before declaring a code change done, and as the source pass for /pii-leakage-check.
---

# PII Safety Scan

The single Kotlin-side personal-data scan, enforcing `rules/pii-handling.md`. Read-only, and it **never prints a personal-data value** — a finding is `file:line` + field name + the missing control.

Infrastructure-layer PII (encryption at rest, residency, retention, backups) is a different surface: `komdosh-dev-infra-core`'s `/pii-audit`.

## Depth

`depth=fast` (default) — families 1–4 over touched `*.kt`, cheap enough to run before every `run-verification`. `depth=audit` — all seven over the whole service, feeding a classified report.

**Depth changes coverage, not standards.** A leak found at `fast` is the same leak.

## Lexicon

Direct (`email`, `phone`, `firstName`/`lastName`, `address`, `postcode`, `dob`) · government (`ssn`, `passport`, `nationalId`, `taxId`) · financial (`iban`, `card`/`pan`, `cvv`) · location (`lat`/`lon`/`geo`) · every `@Pii`-annotated project type.

At `depth=audit`, read the domain model for the *real* PII-bearing types rather than trusting the generic list. **A surrogate ID (`userId`, `orderId`) is not PII** — a hit on one is not a finding.

## Families

| # | What | Severity | Depth |
|---|---|---|---|
| 1 | PII field interpolated into a `log.*` call or a thrown message | BLOCKER | fast |
| 2 | PII in `span.setAttribute`, meter `.tag(...)`, or `MDC.put` | WARNING | fast |
| 3 | A PII-wrapping `value`/`data class` with no redacting `toString()` | WARNING | fast |
| 4 | PII in an event/Avro payload, or unmasked in a `*Response`/`*Dto` | WARNING | fast |
| 5 | `ProblemDetail.detail`/`.setProperty` built from a PII field | BLOCKER | audit |
| 6 | A PII field reachable **without an ownership check** — another subject's data | BLOCKER | audit |
| 7 | No discoverable erasure/access path for a subject | WARNING | audit |

Family 1 applies on **every** profile — a debug-only leak is still a leak in the aggregator. Family 3 is the backstop: without it, any incidental log of the enclosing object leaks the field no matter how careful family 1 is. Family 6 coordinates with `match-routes-to-filters`.

```bash
grep -nE 'log\.(info|debug|warn|error|trace)\(.*\b(email|phone|address|passport|ssn|nationalId|card|iban|fullName)\b'
```

Keep each pattern tight — a false positive is cheap, a miss is not.

## Report

One line per finding: `file:line` · field · family · the fix (surrogate ID / redacting `toString()` / mask at the boundary / tokenise). **Never the value.**

State the families that came back clean — a clean verdict needs evidence, not silence. At `depth=fast`, any family 1–4 hit recommends `/pii-leakage-check` for the classified pass.
