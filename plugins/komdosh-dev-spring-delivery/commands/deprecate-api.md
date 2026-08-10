# /deprecate-api <fully-qualified-symbol> [--sunset=vX.Y.Z] [--replacement="<expression>"]

**Library track only.** Mark a public Kotlin symbol `@Deprecated`, set the sunset version, surface known internal call-sites, run `/abi-check` to confirm the deprecation is backwards-compatible, and add a CHANGELOG breadcrumb under `## [Unreleased]`.

## Steps

- [ ] **Step 1: Validate the symbol argument**

Required positional: a fully-qualified Kotlin symbol — `com.example.lib.MyClass`, `com.example.lib.MyClass.someFunction`, or top-level `com.example.lib.SomeFunctionsKt.someFunction`.

If missing: ask. The agent does not guess.

- [ ] **Step 2: Invoke `library-publisher --mode=deprecate`**

Pass the symbol, sunset (default = current minor + 2), and optional replacement expression.

The agent:
1. Confirms track is library (refuses on service track).
2. Locates the file containing the symbol.
3. Reads the existing definition.
4. Adds the `@Deprecated(...)` annotation with `message`, `replaceWith` (if provided), and `level = WARNING`.
5. Greps for internal call-sites (excluding test sources).
6. Adds a CHANGELOG breadcrumb under `## [Unreleased]` / `### Deprecated`.
7. Runs `/abi-check` to confirm the deprecation is non-breaking.

- [ ] **Step 3: Print the agent's report**

The user sees:
- The annotated symbol's diff.
- Internal call-sites still using the symbol (count + file paths).
- The CHANGELOG line that was added.
- The ABI report classification (must be `deprecated`, not `breaking`).

- [ ] **Step 4: Suggest the commit**

```bash
git add <annotated-file> CHANGELOG.md
git commit -m "feat: deprecate <symbol> — sunset v<version>"
```

If the agent surfaced internal call-sites, recommend a follow-up task:
```
Internal call-sites still using <symbol>: <count>
Recommended: invoke backend-implementer (core) to migrate them before the next release.
```

If the user wants to escalate the deprecation level later:
```
Lifecycle:
  Now:                    level = WARNING (this command)
  One minor before sunset: bump to level = ERROR — re-run /deprecate-api with --escalate
  At sunset:              bump to level = HIDDEN; binary signature retained
  At next major:          remove the symbol entirely (binary break)
```
