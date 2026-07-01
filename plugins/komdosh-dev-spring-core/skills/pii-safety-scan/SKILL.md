---
name: pii-safety-scan
user-invocable: false
allowed-tools: Grep, Glob, Read, Bash(git diff:*)
description: Fast grep-based scan of touched Kotlin for the personal-data (PII) handling violations from rules/pii-handling.md — raw PII field values interpolated into log/trace statements, PII-bearing value classes without a redacting toString(), PII embedded in event payloads or DTO responses without masking, and PII in span attributes or metric tags. Runs in seconds; catches leaks before run-verification or a security audit. Read-only; never prints the personal-data value, only the file:line and the field. Run before declaring a code change done, alongside coroutine-safety-scan.
---

# PII Safety Scan

A seconds-long grep sweep over touched Kotlin for the app-layer PII violations in `rules/pii-handling.md`. The dev-time counterpart to the security plugin's audit-grade `scan-pii-exposure` — cheap, runs during development, catches the obvious leaks before `run-verification`. Read-only, and it **never prints a personal-data value** — a finding is file:line + the field name.

Scope to touched files (`git diff --name-only` against the base) or the module under change. Track as a todo when invoked.

## The PII lexicon

Build the field-name set to grep for: `email`, `phone`, `mobile`, `firstName`/`lastName`/`fullName`, `address`, `street`, `postcode`/`zip`, `dob`/`birth`, `ssn`, `passport`, `nationalId`, `taxId`, `iban`, `card`/`pan`, `cvv`, `lat`/`lon`/`geo`, plus any project types marked `@Pii`. Tune to the domain.

## What it flags

### 1. Raw PII in log/trace statements (WARNING→BLOCKER)
- `log.(info|debug|warn|error|trace)(...)` whose arguments include a PII field or `.value` of a PII value class.
- String interpolation of a PII field into any logged/`throw`n message.
- `grep -nE 'log\.(info|debug|warn|error|trace).*(email|phone|address|passport|ssn|card|iban|fullName)'` — then confirm it's the value, not a surrogate ID.

### 2. PII types without a redacting `toString()` (WARNING)
- A `value class`/`data class` wrapping a PII field that does not override `toString()` to redact — every log of the enclosing object leaks it.

### 3. PII in event payloads / DTO responses (WARNING)
- PII field names in an event/Avro payload class, or in a `*Response`/`*Dto` returned from a controller, without masking/tokenisation. Raw PII crossing the wire or onto a topic.

### 4. PII in observability (WARNING)
- PII field in a `span.setAttribute(...)`, `Span.current()...`, `Counter/Timer ... .tag(...)`, or `MDC.put(...)` — leaks into traces/metrics and (MDC) is coroutine-unsafe too.

## Method

1. Scope to the diff/module; restrict to `*.kt`.
2. Run the four families with `grep -nE`, tuned tight to limit noise. A surrogate ID (`userId`, `orderId`) is fine; the raw value is the finding.
3. For each hit: `file:line`, the PII field, which rule it breaks, and the fix (surrogate ID / redact `toString()` / mask / tokenise). **Never** capture the value.

## Output

```
PII SAFETY SCAN — <scope>  (<n> findings); 0 values disclosed

- <file>:<line>  <field>  <family>  — <fix: log userId instead / add redacting toString() / mask in DTO / drop from tag>
...

Clean families: <the families that returned nothing>
```

State which families came back clean. For a full audit-grade report (error bodies, cross-store exposure, event topics), route to the security plugin's `/pii-leakage-check`; for the infra data lifecycle, to infra-core's `/pii-audit`.
