# /publish-prep

**Library track only.** Validates Maven coordinates, POM completeness (developers, scm, license), signing config, repository creds reachability, sources/javadoc jars, and `-SNAPSHOT` dep cleanliness. Read-only — reports gaps with remediation. Does not publish.

Refuses on the service track.

## Steps

- [ ] **Step 1: Confirm track is library**

Run `read-service-context`. If `kind != library`, REFUSE.

- [ ] **Step 2: Invoke `check-publish-config` skill**

The skill probes:

| Check | What it validates |
|---|---|
| Coordinates | `group`, `artifact`, `version` set; group reverse-DNS-shaped; version not `-SNAPSHOT` if target is a release repo. |
| POM developers | At least one developer with name + email. |
| POM scm | `connection`, `url` reference the actual repo. |
| POM licenses | At least one with a recognised SPDX identifier. |
| POM description + url | Both non-empty. |
| Sources jar | `withSourcesJar()` configured (or equivalent task). |
| Javadoc/Dokka jar | `withJavadocJar()` OR Dokka task wired to a `-javadoc` classifier. |
| Signing | `signing.gnupg.keyName` property OR `ORG_GRADLE_PROJECT_signing*` env vars present. (Does NOT extract or print the key.) |
| Target repository | If publishing to Maven Central via Sonatype: OSSRH credentials present (env or `~/.gradle/gradle.properties`). If GitHub Packages: `GITHUB_TOKEN` present. |
| `-SNAPSHOT` deps | `./gradlew dependencies --configuration runtimeClasspath` — fail if any line contains `-SNAPSHOT`. |
| ABI baseline | `kotlinx.binary-compatibility-validator` plugin applied AND `api/` baseline committed. WARN if missing (not BLOCKER). |

For each check: report PASS / FAIL / WARN with the exact remediation.

- [ ] **Step 3: Compose the report**

```
Publish prep — vX.Y.Z

[OK]    Coordinates:        com.example:my-lib:1.4.0  (group is reverse-DNS, version is non-SNAPSHOT)
[OK]    POM developers:     1 (Andrey Tabakov <ave@example.com>)
[FAIL]  POM scm:            missing — add scm { connection = "..."; url = "..." } to publishing config
[OK]    POM licenses:       1 (MIT)
[OK]    POM description:    "..."  (52 chars)
[OK]    Sources jar:        withSourcesJar() configured
[FAIL]  Javadoc jar:        no javadoc artifact wired — add Dokka or withJavadocJar()
[OK]    Signing:            signing.gnupg.keyName=<masked>
[OK]    OSSRH credentials:  present (env)
[OK]    Snapshot deps:      none in runtimeClasspath
[WARN]  ABI baseline:       kotlinx.binary-compatibility-validator not applied — add to root build.gradle.kts and commit api/<module>.api files

BLOCKERS: 2  (fix before publishing)
WARNINGS: 1  (recommended)
```

- [ ] **Step 4: Suggested follow-ups**

For each FAIL, print the concrete edit. Example:

```kotlin
// build.gradle.kts (publish block)
publishing {
    publications {
        named<MavenPublication>("maven") {
            pom {
                scm {
                    connection.set("scm:git:https://github.com/<org>/<repo>.git")
                    developerConnection.set("scm:git:ssh://git@github.com/<org>/<repo>.git")
                    url.set("https://github.com/<org>/<repo>")
                }
            }
        }
    }
}
```

If the project lacks Dokka:
```
Recommend adding the Dokka plugin:
  plugins { id("org.jetbrains.dokka") version "1.9.+" }
Then wire dokka to javadoc:
  java { withJavadocJar() }  // emits empty jar; replace with dokkaJavadoc
  tasks.named<Jar>("javadocJar") { from(tasks.named("dokkaJavadoc")) }
```

For each WARNING (e.g. ABI baseline missing), add a hint but do not block:
```
WARN: kotlinx.binary-compatibility-validator is not applied. /abi-check will still run via japicmp fallback, but per-version baselines committed to api/ are stronger long-term. Consider adding the plugin in a follow-up.
```

- [ ] **Step 5: Final**

Print BLOCKER count. If 0: state "ready to publish — proceed via library-publisher when /release-prep passes." If non-zero: re-run `/publish-prep` after fixing.

This command never publishes. Publishing is owned by `library-publisher` (invoked by `/release-prep` once readiness is GREEN).
