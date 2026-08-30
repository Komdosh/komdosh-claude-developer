---
description: Decide and apply the next version number from commit history — ABI-load-bearing on the library track, where a breaking delta forces major.
argument-hint: "[target] [--track=service|library] [--dry-run]"
---

# /version-bump

1. `read-service-context` for the track.
2. `detect-release-type` → last tag, commit counts by prefix, breaking count, proposed bump, rationale.
3. **Library track: always run `produce-abi-report`.** Any breaking delta **overrides the commit-derived bump to major**, stated explicitly as an override — commit messages routinely understate a signature change. Additive-only deltas against a `patch` signal are a softer hint that `minor` may be right, since new public API shipped even though no commit said `feat:`.
4. A user-supplied target that is **lower** than the proposal is **refused** with the reason, and proceeds only on explicit confirmation. Equal or higher proceeds.
5. `--dry-run` stops here.
6. Apply the bump at exactly one occurrence — root `build.gradle.kts` `version`, the catalog's project alias, `allprojects { version }`, or `version.properties`. **Touch nothing else in the build.** Show the diff.

Report the transition, the bump type, and whether an ABI override applied.
