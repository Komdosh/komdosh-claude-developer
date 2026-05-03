# /review [--focus dim1,dim2,...]

Review the current diff using `change-reviewer`. Optionally narrow the review to specific dimensions.

## Usage

```
/review
/review --focus correctness,abstraction-quality
/review --focus contract-hygiene,observability
```

Valid dimension names: `correctness`, `contract-hygiene`, `observability`, `abstraction-quality`, `future-proofing`

## Steps

- [ ] **Step 1: Get the diff**

```bash
git diff main..HEAD
```

If empty, check staged changes:
```bash
git diff --cached
```

If both are empty: "No changes to review. Make or stage some changes first."

- [ ] **Step 2: Identify affected modules**

From the diff file paths, list the Gradle modules changed.

- [ ] **Step 3: Invoke change-reviewer**

Pass the diff to `change-reviewer`. If `--focus` was specified, include the focus list in the prompt:
"Review this diff. Focus only on: [dim1, dim2]. Skip other dimensions."

- [ ] **Step 4: Run verification on affected modules**

Run `run-verification` skill on each affected module.

- [ ] **Step 5: Present findings**

Present findings from `change-reviewer` ordered by severity (all BLOCKERs first, then WARNINGs, then INFOs).

Present verification results (tests, compile, detekt).

- [ ] **Step 6: Conclude**

End with the `change-reviewer` recommendation:
`MERGE` / `FIX BLOCKERS FIRST (N blockers)` / `DO NOT MERGE`
