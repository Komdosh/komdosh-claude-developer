# Gradle Build

Read `gradle/libs.versions.toml`, the affected `build.gradle.kts`, and `buildSrc/` before editing.

- **The version catalog is the only place a version lives.** A version literal in a `build.gradle.kts` drifts from the catalog unnoticed.
- **`implementation` over `api`.** `api` puts the dependency on every consumer's compile classpath, so a bump becomes everyone's problem and the module boundary stops being enforceable.
- Shared build logic goes in one `buildSrc` convention plugin, applied by id — never inlined per module.
- **Never invent a version number.** Resolve it deliberately (registry/Context7 MCP, or the library's release page) and say which you picked and why. A guess is a build failure or a silent downgrade.
- Verify: `./gradlew :<module>:build -x test`. A build edit that was not compiled is not done.

Scope is Gradle files only. Dockerfiles and Compose are `rules/local-dev.md`; manifests and CI are the `komdosh-dev-infra-*` plugins. A Gradle change never edits them in the same pass.
