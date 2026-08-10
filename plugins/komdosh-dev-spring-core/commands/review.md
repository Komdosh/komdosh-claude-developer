# /review [--focus dim1,dim2,...]

Review the current diff with `code-reviewer` at `scope=diff`.

For a whole-service pre-production audit rather than a diff, use `/service-health` (the same agent at `scope=service`).

## Usage

```
/review
/review --focus correctness,abstraction-quality
/review --focus contract-hygiene,observability
```

Valid dimensions: `correctness`, `contract-hygiene`, `observability`, `abstraction-quality`, `future-proofing`

## Steps

- [ ] **Step 1: Confirm the base branch, then get the diff**

The base is usually `main` in this repo; confirm it if the branch flow is unclear rather than assuming.

```bash
git diff main...HEAD
```

If empty, check staged changes:

```bash
git diff --cached
```

If both are empty: "No changes to review. Make or stage some changes first." Stop.

- [ ] **Step 2: Identify affected modules**

From the diff paths, list the Gradle modules changed.

- [ ] **Step 3: Invoke `code-reviewer`**

Pass `scope=diff`, the base branch, and the diff. If `--focus` was given, include it: "Focus only on: [dim1, dim2]. Skip other dimensions."

- [ ] **Step 4: Run verification on the affected modules**

Run the `run-verification` skill on each affected module.

- [ ] **Step 5: Present findings**

Findings ordered by severity — all BLOCKERs, then WARNINGs, then INFOs — followed by the verification results (tests, compile, detekt).

- [ ] **Step 6: Conclude**

End with the agent's recommendation: `MERGE` / `FIX BLOCKERS FIRST (N blockers)` / `DO NOT MERGE`, and its stated evidence for anything it called clean.
