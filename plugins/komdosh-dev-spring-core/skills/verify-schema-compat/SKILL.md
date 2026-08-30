---
name: verify-schema-compat
user-invocable: false
description: "Compares a proposed Avro schema against its previous version (from git, or the live registry, or a referenced subject snapshot) and returns a structured compatibility verdict — BACKWARD / FORWARD / FULL / BREAKING — plus the changed fields and the rule each change violates. Read-only. Used by /avro-evolve and the avro-schema-author agent before any non-trivial schema change ships."
---

# Verify Schema Compat

Run before **every** non-greenfield schema change. Read-only: it never registers a schema (registration is a deployment action) and never auto-fixes a breaking change — it reports, the caller decides bump-in-place vs. version-up.

## 1. Resolve the previous version

Registry (`downloadSchemas`, if the plugin and URL are available) → else `git show HEAD:<path>` → else exit `verdict: NEW`.

For an IDL project, compile `.avdl` with `avro-tools idl2schemata` first; the diff is always between compiled `.avsc`.

## 2. Pick the engine — most authoritative first

1. **Confluent `testSchemasTask`** — runs the registry's real algorithm against the subject's own compat mode.
2. **`avro-tools compatibility <previous> <proposed>`**.
3. **In-process `SchemaCompatibility.checkReaderWriterCompatibility`** — print the script; execution belongs to the calling command.
4. **Structural diff** against the evolution table in `rules/avro-schemas.md` — always available, least rigorous.

## 3. Classify each change

| Class | Verdict |
|---|---|
| Added optional with default · removed optional · renamed **with** alias · enum symbol added **with** enum default · doc-only | Safe |
| Added required **with** default | BACKWARD only — not FORWARD |
| Default changed | Usually BACKWARD, occasionally surprising — always surface it |
| Added required **without** default · removed required · renamed **without** alias · default removed · enum symbol added without enum default · enum symbol reordered or removed | **BREAKING** |
| Type changed | **BREAKING by default**, including widening — Avro promotes only a few pairs; only the diff engine can clear it |

Roll up: all-safe → `FULL`; no breaking → `BACKWARD` or `FORWARD` by direction; any breaking → `BREAKING`.

## 4. Report

JSON — subject, previous and proposed sources, engine used, verdict, and per-change `{field, class, old, new, note}` — plus a short advisory.

- **A `BACKWARD` verdict is not universal safety.** Surface the subject's *own* compat mode: a registry configured `FULL` will reject a schema this reports as `BACKWARD`. Apicurio uses the same mode names and the same mapping.
- On `BREAKING`, the report must also give the next-version filename and topic name (bump the record's trailing `V<n>` and the topic's `.v<n>` together).
