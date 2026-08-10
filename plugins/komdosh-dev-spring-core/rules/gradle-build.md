# Gradle Build Rules

Build changes are precise and minimal. Read `gradle/libs.versions.toml`, the affected `build.gradle.kts`, and `buildSrc/` before editing any of them.

## Version catalog is the only place versions live

Every dependency goes through `gradle/libs.versions.toml`. A version literal in a `build.gradle.kts` is a defect — it drifts from the catalog and nobody notices.

```toml
[versions]
new-lib = "1.2.3"

[libraries]
new-lib = { module = "com.example:new-lib", version.ref = "new-lib" }
```

```kotlin
dependencies {
    implementation(libs.new.lib)      // runtime
    testImplementation(libs.new.lib)  // test only
    api(libs.new.lib)                 // leaks onto consumers' compile classpath — use sparingly
}
```

Prefer `implementation` over `api`. `api` puts the dependency on every consuming module's compile classpath, so a version bump becomes everyone's problem and the module boundary stops being enforceable.

## Convention plugins, not copy-paste

Shared build logic lives in one `buildSrc` convention plugin, never inlined per module:

```kotlin
// buildSrc/src/main/kotlin/kotlin-service.gradle.kts
plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    id("io.gitlab.arturbosch.detekt")
}

kotlin { jvmToolchain(21) }
tasks.test { useJUnitPlatform() }
```

```kotlin
// every module
plugins { id("kotlin-service") }
```

## Never invent a version

If a needed library is absent from the catalog, resolve its current version deliberately — the Context7/registry MCP or the library's own release page — and say which version you picked and why. A guessed version number is a build failure or, worse, a silent downgrade.

## Verify after every build change

```bash
./gradlew :<affected-module>:build -x test 2>&1 | tail -15
```

Expected: `BUILD SUCCESSFUL`. A build edit that isn't compiled is not done.

## Scope

Gradle files only: `build.gradle.kts`, `settings.gradle.kts`, `buildSrc/`, `gradle/libs.versions.toml`. Container, CI, and Kubernetes concerns are `rules/local-dev.md` and the `komdosh-dev-infra-*` plugins — a Gradle change never edits a Dockerfile or a manifest in the same pass.
