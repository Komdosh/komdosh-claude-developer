---
name: pre-edit-impact-check
description: Before editing a class, function, or DTO field that may have callers, list every file that references it so the edit doesn't break N call sites silently. Use when renaming, changing a signature, removing a field, or deleting a public symbol. Skip for purely internal/private symbols and brand-new code that has no callers yet.
---

# Pre-Edit Impact Check

Run **before the first edit** when the change touches something externally visible: a rename, a signature or nullability change, a removed DTO/`value class` field, a deletion, or any change to a port interface in `application/ports/`.

Skip for `private`/file-local symbols, brand-new code with no callers, body-only changes, and purely additive edits (a new optional parameter with a default).

## 1. Direct references

Prefer the IDE index (`ide_find_references`) — it handles imports, overloads, and generics. Grep is the fallback:

```bash
grep -rn "\b<SymbolName>\b" --include='*.kt' --include='*.java' .
```

For a value class used as an identifier type, grep **both** `OrderId(` (constructions) and `: OrderId` (parameter types) — one alone misses half the sites.

## 2. Indirect references — the ones that break silently

| Channel | How to find |
|---|---|
| `typealias` re-exports | `grep -rn "typealias.*<Symbol>"` |
| Implementations / subclasses | `ide_find_implementations`, else `grep -rn ":\s*<Symbol>\b"` |
| **Reflection and qualified-name strings** — `@ConditionalOnClass`, `Class.forName`, YAML/properties | `grep -rn "<package>.<Symbol>" --include='*.kt' --include='*.yaml' --include='*.properties'` |
| jOOQ/Avro generated code | `find . -path '*/build/generated/*' \| xargs grep -l '<Symbol>'` |
| Architecture tests | `grep -rn '<Symbol>' tests/architecture/` |

**Don't filter out test sites** — test breakage is real breakage. Group them separately so the cost is visible.

## 3. Recommend an approach

| Situation | Approach |
|---|---|
| ≤5 sites, one module, all mechanical | In-place rename in one diff |
| >5 sites, crosses modules, or any site needs a semantic change | Deprecate-then-remove — add the new API, `@Deprecated` the old, migrate in a follow-up |
| Public API in `api/` that other services consume | Dual-publish per `rules/api-conventions.md`, coordinated by an ADR |
| A port interface in `application/ports/` | **The port and every `adapters/outbound/` implementation must land in one commit** |

## 4. Report

Direct count and modules · indirect count and channels · cross-module yes/no · recommended approach.

**Above ~50 direct references, stop and ask the user** — that is a refactor, not a tweak.
