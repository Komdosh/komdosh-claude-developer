---
name: pii-safety-scan
user-invocable: false
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git status:*)
description: Scans Kotlin/Spring source for personal-data (PII) exposure on the data-in-motion surface — raw PII in log and trace statements, PII in span attributes / metric tags / MDC, PII value classes without a redacting toString(), unmasked PII in response DTOs, PII in event and Avro payloads, PII in error-response bodies, and subject-rights reachability. Runs at depth=fast (four families, seconds, for the dev loop) or depth=audit (all seven families, for a classified security report). Read-only; reports file:line and the PII field, and never prints the personal-data value itself. Use before declaring a code change done, and as the source pass for /pii-leakage-check.
---

# PII Safety Scan

The single Kotlin-side personal-data scan. Enforces `rules/pii-handling.md`. Read-only, and it **never prints a personal-data value** — a finding is `file:line` + the field name + the missing control.

Infrastructure-layer personal data (encryption at rest, residency, retention, backups) is a different surface: that's the `komdosh-dev-infra-core` plugin's `/pii-audit`.

## Depth

Take `depth` from the caller; default `fast`.

- **`depth=fast`** — families 1–4. A seconds-long grep over touched files, cheap enough to run on every change before `run-verification`.
- **`depth=audit`** — all seven families, over the whole service. Feeds a classified BLOCKER/WARNING/INFO report (`komdosh-dev-spring-quality`'s `rules/security-audit.md`).

Depth changes coverage, not standards — a leak found at `fast` is the same leak.

## Scope

`depth=fast`: touched files (`git diff --name-only` against the base) or the module under change.
`depth=audit`: the whole service.

Restrict to `*.kt`. Track as a todo when invoked.

## The PII lexicon

Build the field-name set before grepping:

- **Direct identifiers** — `email`, `phone`, `mobile`, `firstName`/`lastName`/`fullName`, `address`, `street`, `postcode`/`zip`, `dob`/`birth`
- **Government IDs** — `ssn`, `passport`, `nationalId`, `taxId`
- **Financial** — `iban`, `card`/`pan`, `cvv`
- **Location** — `lat`/`lon`/`geo`
- Plus every project type annotated `@Pii`.

Tune to the domain — at `depth=audit`, read the domain model to find the real PII-bearing types rather than trusting the generic list. A surrogate ID (`userId`, `orderId`) is *not* PII; a hit on one is not a finding.

## Families

### 1. Raw PII in log / trace statements — BLOCKER

```
grep -nE 'log\.(info|debug|warn|error|trace)\(.*\b(email|phone|address|passport|ssn|nationalId|card|iban|fullName)\b'
```

Also: string interpolation of a PII field into any logged or `throw`n message. A hit is a leak unless the argument is a surrogate ID or an already-masked form. Applies on **every** profile — a debug-only leak is still a leak in a log aggregator.

### 2. PII in observability — WARNING

PII fields in `span.setAttribute(...)`, `Attributes.of(...)`, meter `.tag(...)`, or `MDC.put(...)`. Traces and metrics are retained and fanned out widely; MDC is coroutine-unsafe on top of it (`rules/kotlin-coroutines.md`).

### 3. PII types without a redacting `toString()` — WARNING

A `value class` / `data class` wrapping a PII field that doesn't override `toString()` to redact. This is the backstop control: without it, any incidental log of the enclosing object leaks the field, no matter how careful family 1 is.

### 4. PII in event payloads and response DTOs — WARNING

- PII field names in an event/Avro payload class (producer side) with no documented reason a tokenised reference wouldn't do. The topic retains and fans out the value.
- `*Response`/`*Dto` classes returned from controllers exposing raw PII where a masked form (`j***@x.com`, `**** 4242`) satisfies the contract.

### 5. PII in error responses — BLOCKER *(audit)*

`@ExceptionHandler` / `WebExceptionHandler` bodies that build `ProblemDetail.detail` or `.setProperty(...)` from a PII field, or from a domain object containing one. Overlaps `check-error-leakage`; here specifically for personal data.

### 6. Cross-subject exposure — BLOCKER *(audit)*

A response that can return **another** subject's PII — a PII field reachable without an ownership check. Coordinate with the auth audit (`match-routes-to-filters`).

### 7. Subject-rights reachability — WARNING/INFO *(audit)*

Whether the service has a discoverable erasure/access path for a subject's PII (delete-user / export-user). Absence is WARNING; INFO if genuinely outside the reviewed scope.

## Method

1. Scope per `depth`; restrict to `*.kt`.
2. Run each family with `grep -nE`, tuned tight to limit noise. A false positive is cheap; a miss is not.
3. For each hit capture `file:line`, the PII field, the family, and the fix — surrogate ID / redacting `toString()` / mask at the boundary / tokenise. **Never capture the value.**

## Output

```
PII SAFETY SCAN — <scope>  depth=<fast|audit>  (<n> findings; 0 values disclosed)

- <file>:<line>  <field>  <family>  — <fix>
...

Scanned: <n> log sites, <n> handlers, <n> response DTOs, <n> event payloads
Clean families: <the families that returned nothing>
```

Always state which families came back clean — a clean verdict needs evidence, not silence.

At `depth=fast`, if anything lands in families 1–4, recommend `/pii-leakage-check` for the full classified pass.
