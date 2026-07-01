---
name: scan-pii-exposure
user-invocable: false
allowed-tools: Grep, Glob, Read
description: Audit-grade scan of a Kotlin/Spring service for personal-data (PII) exposure on its data-in-motion surface — raw PII in log/trace statements (any profile), PII in span attributes / metric tags / MDC, PII in @ExceptionHandler / ProblemDetail error bodies, unmasked PII in response DTOs beyond entitlement, PII embedded in event/Avro payloads without a tokenised alternative, and PII value classes without a redacting toString(). Classifies findings per rules/security-audit.md; cites file:line and the PII field; never prints the value. Read-only. Consumed by the security-auditor agent and the /pii-leakage-check command.
---

# Scan PII Exposure

The audit-grade counterpart to core's fast `pii-safety-scan` — a thorough sweep of a service's data-in-motion surface for personal-data exposure, feeding a classified report. Read-only, and it **never prints a personal-data value**: a finding is file:line + PII field + the control that's missing. Classify per `rules/security-audit.md` (PII-exposure category); the underlying discipline is `core/rules/pii-handling.md`.

## Step 1: Build the PII field lexicon

Direct identifiers (`email`, `phone`, `firstName`/`lastName`/`fullName`, `address`, `street`, `postcode`/`zip`, `dob`/`birth`), government IDs (`ssn`, `passport`, `nationalId`, `taxId`), financial (`iban`, `card`/`pan`, `cvv`), location (`lat`/`lon`/`geo`), and every project type annotated `@Pii`. Tune to the domain — read the domain model to find the real PII-bearing types.

## Step 2: Logging & tracing (BLOCKER)

- `grep -nE 'log\.(info|debug|warn|error|trace)\(.*\b(email|phone|address|passport|ssn|nationalId|card|iban|fullName)\b'` — a hit is a leak unless the argument is a surrogate ID or an already-masked form.
- PII in `span.setAttribute(...)`, `Attributes.of(...)`, meter `.tag(...)`, or `MDC.put(...)`.
- Confirm the value is the personal data, not a surrogate (`userId`, `orderId`) — surrogates are fine.

## Step 3: Error responses (BLOCKER)

- `@ExceptionHandler` / `WebExceptionHandler` bodies that build `ProblemDetail.detail` / `.setProperty(...)` from a PII field or a domain object containing one. (Overlaps `check-error-leakage`; here specifically for personal data.)

## Step 4: Response DTOs (WARNING/BLOCKER)

- `*Response` / `*Dto` classes returned from controllers that expose raw PII where a masked form (`j***@x.com`, `**** 4242`) would satisfy the contract → WARNING.
- A response that can return **another** subject's PII (missing ownership check on a PII field) → BLOCKER (coordinate with the auth audit).

## Step 5: Event payloads (WARNING)

- PII field names in an event/Avro payload class (producer side) without a documented reason a tokenised reference wouldn't work. The topic retains and fans out the PII.

## Step 6: Type hygiene (WARNING)

- A `value class` / `data class` wrapping a PII field with no `toString()` override that redacts — the backstop control is missing, so any incidental log of the enclosing object leaks it.

## Step 7: Subject-rights reachability (WARNING/INFO)

- Note whether the service has a discoverable erasure/access path for a subject's PII (a delete-user / export-user flow). Absence is WARNING (INFO if genuinely out of the reviewed scope).

## Output

Return structured findings for the agent to classify and report:

```
PII EXPOSURE — <scope>  (0 values disclosed)

- <file>:<line>  <PII field>  <category: log|trace|error-body|dto|event|type|rights>  — <fix: surrogate ID / redact / mask / tokenise>
...

Scanned: <n> log sites, <n> handlers, <n> response DTOs, <n> event payloads
Clean categories: <what came back clean>
```

Never print a personal-data value — location + field + missing control only.
