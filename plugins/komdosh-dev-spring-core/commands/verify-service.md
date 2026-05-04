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

- [ ] **Step 2: Run run-verification skill per module**

The `run-verification` skill is module-targeted. Loop it once per module discovered in Step 1, in this order:
1. `domain` and `application` first (fastest, fail loudly on logic errors)
2. `adapters/inbound`, `adapters/outbound` next
3. `boot` last

For the boot compile check, run it once at the end (not per module):
```bash
./gradlew :boot:compileKotlin 2>&1 | tail -20
```

For detekt, run once across all modules at the end:
```bash
./gradlew detekt 2>&1 | tail -30
```

If a module fails, fix it before moving to the next — do not batch failures.

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
