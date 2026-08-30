---
description: Run narrowest-first verification across every module — module tests, then one boot compile, then detekt. Safe at any point; does not need a clean tree.
---

# /verify-service

1. Discover modules from `build.gradle.kts` files (excluding `build/`, `.gradle/`, `buildSrc/`).
2. Run module tests in order — `domain` and `application` first (fastest, fail loudest on logic errors), then the adapters, then `boot`. **Fix a failing module before moving on; do not batch failures.**
3. `./gradlew :boot:compileKotlin` once at the end, then `./gradlew detekt` once across all modules.
4. Report tests / compile / detekt separately, listing failing classes and violated rules.
5. Route what's left: test failures → `/test-fix` · compile failures → `backend-implementer` · style violations → `cleanuper`.
