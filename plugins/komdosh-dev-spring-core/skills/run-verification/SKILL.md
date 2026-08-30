---
name: run-verification
description: "Run narrowest-first Gradle verification after code changes: targeted module tests first, then boot compile check, then detekt on affected modules. Auto-fires after any code change. Always confirm BUILD SUCCESSFUL before reporting done."
---

# Run Verification

Run after **any** code change, before reporting done — including changes that look trivial.

Three steps, narrowest first. Convert paths to Gradle notation (`adapters/outbound` → `:adapters:outbound`).

1. `./gradlew :<module>:test --tests "<FQCN>"` — or the whole module's tests when no specific class changed.
2. `./gradlew :boot:compileKotlin` — catches wiring errors that unit tests never see.
3. `./gradlew :<module>:detekt`

**Never skip a later step because an earlier one passed**, and never run `./gradlew build` when a narrower target works. On a failure, read the full output, diagnose, fix, and re-run from that step.

Report tests / compile / detekt separately with the failing names or violations. **The task is done only when all three return `BUILD SUCCESSFUL`** — report anything less as the failure it is.
