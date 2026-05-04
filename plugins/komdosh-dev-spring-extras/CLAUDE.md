# CLAUDE.md — komdosh-dev-spring-extras

Niche tooling on top of `komdosh-dev-spring-core`. Install only if you actually need one of these.

## What it adds

| Command | Agent | What it does |
|---|---|---|
| [`/upgrade <lib>`](commands/upgrade.md) | [`dependency-upgrader`](agents/dependency-upgrader.md) | Bumps **one** library at a time in `gradle/libs.versions.toml`. Reads upstream changelog, lists breaking changes with affected file globs, runs verification, iterates on compile fixes (capped at 5). Major bumps require user confirmation. |
| [`/detect-flakes`](commands/detect-flakes.md) | [`flaky-test-detector`](agents/flaky-test-detector.md) | Re-runs a test class (or last-failed) N times with `--rerun-tasks --no-daemon`, parses JUnit XML, classifies each method as DETERMINISTIC PASS / DETERMINISTIC FAIL / FLAKY, appends to `docs/flakes.md`. Surfaces evidence; does not fix — routes to the right specialist. |
| [`/load-test-new`](commands/load-test-new.md) | [`load-test-scaffolder`](agents/load-test-scaffolder.md) | Scaffolds Gatling simulations in the `load-tests/` module. |

## Dependencies

Requires `komdosh-dev-spring-core`. The dependency-upgrader hands off to `backend-implementer` (core) when a bump requires application-code refactoring beyond compile fixes; flaky-test-detector hands off to `test-writer` (core) for coroutine-timing flakes and to `integration-debugger` (core) for container-readiness flakes.
