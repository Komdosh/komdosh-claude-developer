---
description: Scaffold a Gatling Kotlin simulation in the load-tests module over the service's HTTP surface, with a realistic ramp profile and latency assertions.
argument-hint: "[scenario name]"
---

# /load-test-new

`load-test-scaffolder`.

**Requires Gatling in the version catalog** — the agent stops rather than inventing a version.

Produces the `load-tests/` module wiring and a simulation with a property-driven base URL, a ramp-then-sustain profile, and p95/success-rate assertions in the simulation itself.

Verified with `:load-tests:gatlingClasses`. **The agent does not run the load test** — that is your call, against a target you choose.
