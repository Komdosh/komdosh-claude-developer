---
name: produce-abi-report
user-invocable: false
description: "Library track. Diffs the public Kotlin/Java API surface against the last released tag. Prefers kotlinx.binary-compatibility-validator (api/<module>.api baselines); falls back to japicmp against the published jar. Per-symbol classification: added / deprecated / changed-signature / removed. Drives /version-bump on the library track. Read-only on source; writes one report doc."
---

# Produce ABI Report

Library track only. **The report is the source of truth for whether a bump must be major** — it outranks the commit-derived proposal.

**Never run `apiDump`.** The committed `api/<module>.api` baseline *is* the prior release's signature; overwriting it destroys the very diff this skill exists to compute. Updating the baseline is a deliberate developer (or CI-on-tag) action. Never decompile dependency jars either — this works against the project's own outputs.

## Base and backend

Base is the newest non-pre-release tag, unless the caller overrides it.

- **`kotlinx.binary-compatibility-validator` present with committed baselines** → diff `git show <tag>:api/<module>.api` against the working copy, per module (per target on Multiplatform). Detect the plugin through a `build-logic/` convention plugin too, not just the root build file.
- **Otherwise → japicmp** against the published jar at the base tag, cross-checked against source so a symbol carrying `@Deprecated` is classified `deprecated` rather than a bare signature change.
- **Neither workable** → do not guess. Report the gap and recommend adding the validator with a committed baseline.

## Classification

| Delta | Class |
|---|---|
| A public symbol present only at HEAD | added |
| Present only at base | **removed — breaking** |
| Present in both with different signatures | **changed-signature — breaking** |
| Gained `@Deprecated` | deprecated |
| **A new member in an existing `sealed` hierarchy** | **breaking** — downstream `when` exhaustiveness fails |

Additive is additive: new symbols and new defaulted parameters are not breaking. The sealed case is the one that looks additive and is not.

## Recommended bump

Any breaking → **major** · any added → minor · only deprecations → **minor** (a deprecation is a public API change) · nothing → patch.

## Output

`docs/release/abi-v<version>.md` plus JSON — `base`, `head`, `backend`, per-class delta counts, `recommended_bump`, `report_path` — consumed by `/version-bump`, the readiness gate, and `release-coordinator`.
