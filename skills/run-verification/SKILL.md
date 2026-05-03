---
name: run-verification
description: "Run narrowest-first Gradle verification after code changes: targeted module tests first, then boot compile check, then detekt on affected modules. Auto-fires after any code change. Always confirm BUILD SUCCESSFUL before reporting done."
---

# Run Verification

## When to Use

Use this skill after **any code change** before reporting the task as done.
Run it even if you believe the change is trivial — Gradle catches type errors and detekt catches style issues the agent misses.

## Do NOT

- Skip any step because an earlier step passed.
- Report success before all three steps have returned `BUILD SUCCESSFUL`.
- Run `./gradlew build` when a narrower task will do — it rebuilds everything unnecessarily.

## Steps

- [ ] **Step 1: Identify affected module(s)**

From the edited file paths, determine which Gradle module(s) were touched.
Convert directory path to Gradle notation: `adapters/outbound` → `:adapters:outbound`

- [ ] **Step 2: Run the narrowest test target**

If a specific test class was added or modified:
```bash
./gradlew :<module>:test --tests "<FullyQualifiedClassName>" -i 2>&1 | tail -40
```

If no specific test class:
```bash
./gradlew :<module>:test 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`
If FAILED: read the full failure output, diagnose, fix, then re-run before proceeding.

- [ ] **Step 3: Run the boot compile check**

```bash
./gradlew :boot:compileKotlin 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`
This catches wiring errors in `boot/` that unit tests won't.

- [ ] **Step 4: Run detekt on affected module(s)**

```bash
./gradlew :<module>:detekt 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`
If violations are listed: fix them or report them explicitly (don't silently ignore).

- [ ] **Step 5: Report result**

State clearly:
- Tests: PASS / FAIL (list failing test names)
- Compile: SUCCESS / FAILURE
- Detekt: CLEAN / N violations (list them)

Only report the task as done if all three are green.
