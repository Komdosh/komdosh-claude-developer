# /test-fix

Fix failing tests one class at a time. Runs the test suite to find failures, works through them one by one, and confirms each is green before moving to the next.

## Steps

- [ ] **Step 1: Find all failing tests**

```bash
./gradlew test 2>&1 | grep -E "FAILED|ERROR" | grep -v "^$" | head -30
```

If no failures: "All tests pass. Nothing to fix."
If failures found: list them grouped by module.

- [ ] **Step 2: Pick the first failing class**

Take the first failing test class from the list. State: "Fixing: `<Module>:<ClassName>`"

- [ ] **Step 3: Run the class in isolation with full output**

```bash
./gradlew :<module>:test --tests "<FullyQualifiedClassName>" --info 2>&1 | tail -80
```

Read the complete failure output including stack trace.

- [ ] **Step 4: State a hypothesis**

Before making any change, state: "I believe this fails because: <reason>."
Identify whether the bug is in the test or in the production code.

- [ ] **Step 5: Make the minimal fix**

Fix exactly what causes this failure. Do not refactor surrounding code.
- If the test assertion is wrong: fix the test.
- If the production code is wrong: fix the production code (use `backend-implementer` for complex changes).
- If the test setup is wrong: fix the setup.

- [ ] **Step 6: Re-run the isolated class**

```bash
./gradlew :<module>:test --tests "<FullyQualifiedClassName>" 2>&1 | tail -15
```

Expected: `BUILD SUCCESSFUL` with the test class passing.
If still failing: revisit the hypothesis. Do not move on.

- [ ] **Step 7: Confirm green, then move to the next class**

State: "`<ClassName>` is green."
Repeat from Step 2 for the next failing class.

## Do NOT

- Fix multiple test classes in a single edit.
- Change test assertions to match wrong production behavior.
- Mark a test as `@Disabled` or `@Ignore` without explicit user approval.
- Move on to the next class until the current one is confirmed green.
