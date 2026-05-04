---
name: pre-edit-impact-check
description: Before editing a class, function, or DTO field that may have callers, list every file that references it so the edit doesn't break N call sites silently. Use when renaming, changing a signature, removing a field, or deleting a public symbol. Skip for purely internal/private symbols and brand-new code that has no callers yet.
---

# Pre-Edit Impact Check

## When to Use

Run this skill **before** the first `Edit` tool call on a file when the change touches anything externally visible:

- Renaming a class, method, or property
- Changing a method signature (parameters, return type, nullability)
- Removing or renaming a field on a `data class` / DTO / `@JvmInline value class`
- Deleting a function, file, or module
- Changing the contract of a port interface in `application/ports/`

Do NOT run when:

- The symbol is `private` or file-local
- You're adding a new symbol that has no callers yet
- You're changing only the body of a function (no signature change)

## Output

A markdown summary written to the conversation (not to a file). Format:

```
Impact: <symbol> in <file>
  Direct references: <N> in <M> files
    <file:line> - <one-line context>
  Indirect references (via re-exports / typealias / inheritance): <K>
    ...
  Recommended approach: <one of: in-place rename | deprecate-then-remove | dual-publish>
```

## Steps

- [ ] **Step 1: Identify the symbol's exact name and current declaration**

Read the file containing the symbol. Note the exact identifier including package, e.g. `com.example.orders.application.ports.OrderRepository.findById`.

- [ ] **Step 2: Search for direct references**

Use the IDE index when available (highest accuracy):

```
mcp__intellij-index__ide_find_references  (preferred — semantic, handles overloads + imports)
```

Fall back to a grep when the IDE is not available:

```bash
# class / interface / enum / object
grep -rn "\b<SymbolName>\b" --include='*.kt' --include='*.java' \
  -l 2>/dev/null | sort | uniq

# member function / property — narrow with a dot prefix when results explode
grep -rn "\.<methodName>\b" --include='*.kt' .
```

For value classes used as identifier types (e.g. `OrderId`), grep both `OrderId(` (constructions) and `: OrderId` (parameter types).

- [ ] **Step 3: Search for indirect references**

| Indirect channel | How to find |
|---|---|
| Re-exports (`typealias`, `package-info` aliases) | `grep -rn "typealias.*<SymbolName>" --include='*.kt' .` |
| Subclasses / implementations | `mcp__intellij-index__ide_find_implementations` (preferred), or `grep -rn ":\s*<SymbolName>\b" --include='*.kt' .` |
| Reflection / qualified-name strings (Spring `@ConditionalOnClass`, jOOQ `Class.forName`, log `T::class.java.name`) | `grep -rn "<package>\.<SymbolName>" --include='*.kt' --include='*.yaml' --include='*.properties' .` |
| jOOQ generated code (NOT in main sources) | `find . -path '*/build/generated/*' -name '*.kt' \| xargs grep -l '<SymbolName>' 2>/dev/null` |
| Architecture tests | `grep -rn '<SymbolName>' tests/architecture/ 2>/dev/null` |

- [ ] **Step 4: Classify call sites**

Group by module (`domain`, `application`, `adapters/inbound`, `adapters/outbound`, `boot`, `tests`). A change that ripples into multiple modules is more disruptive than one that stays within a single module.

For each call site, record one line of context (the line containing the reference + a few words before/after). This lets the edit decide whether each site needs a mechanical update or a semantic one.

- [ ] **Step 5: Recommend an approach**

| Situation | Recommended approach |
|---|---|
| ≤ 5 call sites, all within one module, all mechanical | **In-place rename** — edit all sites in the same diff |
| > 5 call sites, or crosses module boundaries, or any site needs semantic adjustment | **Deprecate-then-remove** — add the new API, mark the old one `@Deprecated(level = DeprecationLevel.WARNING)`, migrate sites in a follow-up |
| Public API on the `api/` module that other services consume | **Dual-publish** — keep the old shape on the existing `/v<N>/`; introduce the new shape on `/v<N+1>/` per [`rules/api-conventions.md`](../../rules/api-conventions.md). Coordinate via an ADR (`/adr-new`) |
| Symbol is on a port interface in `application/ports/` | Confirm every implementation in `adapters/outbound/` is updated atomically; the port + adapters MUST land in one commit |

- [ ] **Step 6: Report**

State exactly:

```
Impact check complete for <SymbolName>.
  Direct references:   <N> in <M> files (<list of modules>)
  Indirect references: <K> (<types>)
  Cross-module:        <yes/no>
  Recommended:         <approach>
  Proceed?             (the calling agent decides whether to continue or escalate)
```

If the count is unexpectedly large (> 50 direct references), STOP and ask the user how to proceed — that scale of edit is a refactor, not a tweak.

## Notes

- The IDE index returns higher-fidelity results than grep (handles imports, overloads, generics) but is only available when the JetBrains MCP is connected.
- For test sites: don't filter them out — test breakage is real breakage. But group them separately in the report so the cost-of-change is visible.
- For purely-additive edits (adding a new optional param with a default value, adding a new field with a default), this skill is overkill. Use judgment.
