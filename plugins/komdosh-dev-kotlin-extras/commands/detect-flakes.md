---
description: Re-run tests N times, classify each method as deterministic-pass, deterministic-fail, or flaky, and append the evidence to docs/flakes.md.
argument-hint: "[test-class|pattern|last-failed] [--runs=N]"
---

# /detect-flakes

`flaky-test-detector`. Target defaults to the test files changed on this branch; runs default to 10.

The agent states the execution count before starting and **asks before exceeding 200 executions** — this is slow by construction, since `--rerun-tasks --no-daemon` is what makes the measurement mean anything.

Results append to `docs/flakes.md` so the history stays comparable across runs.

**A deterministic failure is a real bug, not a flake** — that routes to `/test-fix`. Genuine flakes route to `test-writer` (timing) or `integration-debugger` (containers). The detector never fixes anything itself.
