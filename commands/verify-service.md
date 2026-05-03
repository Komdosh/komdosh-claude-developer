# /verify-service

Run narrowest-first verification of the service. Safe to run at any point during development. Does not require a clean state.

## Steps

- [ ] **Step 1: Identify all modules**

```bash
find . -name "build.gradle.kts" \
  -not -path "*/build/*" \
  -not -path "*/.gradle/*" \
  -not -path "*/buildSrc/*" \
  | sed 's|/build.gradle.kts||' | sed 's|^\./||' | sort
```

- [ ] **Step 2: Run run-verification skill**

Run `run-verification` skill across all identified modules.

The skill will:
1. Run tests for all modules
2. Run `:boot:compileKotlin` as a compile check
3. Run detekt on all modules

- [ ] **Step 3: Report full results**

```
Tests:   PASS (N tests) / FAIL (list failing classes)
Compile: SUCCESS / FAILURE (error message)
Detekt:  CLEAN / N violations (list files and rules)
```

- [ ] **Step 4: Offer next steps**

If test failures exist: "Use `/test-fix` to work through test failures one class at a time."
If compile failures exist: "Invoke `backend-implementer` to fix the compile error."
If detekt violations exist: "Use `cleanuper` to fix style violations, or invoke `/review` to see if any are intentional."
If all green: "Service verification passed. All checks are clean."
