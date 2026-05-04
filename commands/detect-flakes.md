# /detect-flakes [test-target] [runs]

Re-run a test class (or set of failing tests) N times to classify each test method as deterministic-pass, deterministic-fail, or flaky. Writes results to `docs/flakes.md`. Does not fix flakes — surfaces them so the right specialist can address.

## Usage

```text
/detect-flakes OrderServiceTest 10        # one class, 10 runs
/detect-flakes com.example.orders.*Test   # a pattern
/detect-flakes last-failed                # whatever failed in the most recent test run
/detect-flakes                             # tests changed in this branch vs main
```

## Steps

- [ ] **Step 1: Resolve target and run count**

If the user provided a target, use it as-is.
If not, default to "tests changed in this branch vs main".
If the user provided a number, that's the run count; otherwise default to 10.

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 3: Confirm scale (only if large)**

If `<resolved-classes> × <runs>` exceeds 200 total executions, ask: "This will run ~N tests; expect ~M minutes. Proceed? (y/n)"

- [ ] **Step 4: Invoke `flaky-test-detector`**

Pass the resolved target and run count. The agent:

1. Identifies the Gradle module per test class.
2. Runs `./gradlew :<module>:test --tests <FQN> --rerun-tasks --no-daemon` N times.
3. Parses `build/test-results/test/TEST-*.xml` after each run.
4. Aggregates per-method pass/fail counts.
5. Classifies each method.
6. Appends a timestamped section to `docs/flakes.md`.
7. Reports the table and routes by classification.

- [ ] **Step 5: Suggest the commit (do not run it)**

If `docs/flakes.md` was modified, print:

```bash
git add docs/flakes.md
git commit -m "docs(flakes): record flake check from $(date -u +%Y-%m-%dT%H:%MZ)"
```

(Optional — many teams choose not to commit the flake log.)

- [ ] **Step 6: Report and route**

Print the agent's table verbatim. Highlight the routing:

- Deterministic failures → "Run `/test-fix` to fix the real bugs."
- Flakes with coroutine-timing root cause → "Invoke `test-writer` to switch to `TestCoroutineScheduler`."
- Flakes with container-startup root cause → "Invoke `integration-debugger` to add wait strategies."

If the run uncovered no flakes, state: "No flakes detected over <N> runs." That is also evidence — record it.
