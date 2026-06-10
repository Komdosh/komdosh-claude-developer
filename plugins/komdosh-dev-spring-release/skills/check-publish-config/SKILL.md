---
name: check-publish-config
user-invocable: false
description: "Library track. Validates Maven coordinates, POM completeness (developers, scm, license, description, url), signing config, target-repository credentials reachability, sources/javadoc jars configured, no -SNAPSHOT deps in runtimeClasspath. Read-only — does not extract keys, does not publish."
---

# Check Publish Config

## When to Use

Use this skill from `/publish-prep`, from `verify-release-readiness-library` as a sub-gate, and from `library-publisher` as a safety re-check before invoking `./gradlew publish`.

Read-only. Reports gaps with concrete remediation. Never extracts secrets.

## Do NOT

- Print the GPG private key, OSSRH password, or `GITHUB_TOKEN`. The skill only confirms the variable is set.
- Run `./gradlew publish` or `publishToMavenLocal`. That belongs to `library-publisher`.
- Treat WARN as FAIL. WARN sub-checks (e.g. ABI baseline missing) inform the user but never block publishing.

## Steps

- [ ] **Step 1: Confirm track is library**

If `kind != library`, REFUSE.

- [ ] **Step 2: Resolve coordinates**

```bash
./gradlew :<module>:properties 2>&1 | grep -E '^(group|name|version):' | head -3
```

Or read directly from `build.gradle.kts`:

```bash
grep -nE 'group\s*=|version\s*=' build.gradle.kts | head -10
```

Validate:
- `group` matches `^[a-z][a-z0-9-]*\.[a-z][a-z0-9.-]*$` (reverse-DNS-shaped).
- `name` (artifact) matches `^[a-z][a-z0-9-]*$`.
- `version` is non-empty and not literally `unspecified` (Gradle's default).

If publishing to a release target: `version` MUST NOT contain `-SNAPSHOT`.

- [ ] **Step 3: Inspect the publication's POM**

```bash
./gradlew :<module>:generatePomFileForMavenPublication 2>&1 | tail -10
pom_file=$(find <module>/build/publications -name 'pom-default.xml' 2>/dev/null | head -1 || true)
[ -f "$pom_file" ] || { echo "POM not generated"; exit 1; }
```

Read the generated POM. Confirm:

| Element | Required | Validation |
|---|---|---|
| `<developers>` | yes | At least one `<developer>` with non-empty `<name>` and `<email>`. |
| `<scm>` | yes | `<connection>` AND `<url>` non-empty. URL points at an actual git repository (heuristic: matches `^https?://(github|gitlab|bitbucket)\.`). |
| `<licenses>` | yes | At least one with `<name>` matching a known SPDX id (`MIT`, `Apache-2.0`, `BSD-3-Clause`, `GPL-3.0-or-later`, `LGPL-2.1-or-later`, `MPL-2.0`, `EPL-2.0`). Custom licenses are allowed but warned. |
| `<description>` | yes | Non-empty, ≥ 20 chars. |
| `<url>` | yes | Non-empty. |

For each, report PASS / FAIL with the missing element name + a Gradle snippet to add it.

- [ ] **Step 4: Confirm sources + javadoc jars**

```bash
./gradlew :<module>:tasks --all 2>&1 | grep -E '(sourcesJar|javadocJar|dokkaJavadocJar|kotlinSourcesJar)' | head -10
```

- PASS if `sourcesJar` task exists.
- PASS if `javadocJar` OR `dokkaJavadocJar` task exists AND is wired into the publication.
- FAIL with the Gradle snippet to wire `withSourcesJar()` / `withJavadocJar()` (or Dokka).

- [ ] **Step 5: Confirm signing**

```bash
# environment variable form
[ -n "$ORG_GRADLE_PROJECT_signingInMemoryKey" ] && echo "ENV-key configured"
[ -n "$ORG_GRADLE_PROJECT_signingPassword" ] && echo "ENV-password configured"

# property form
grep -E 'signing\.gnupg\.keyName|signing\.gnupg\.passphrase' \
  ~/.gradle/gradle.properties gradle.properties 2>/dev/null
```

- PASS if either form is configured.
- FAIL with a one-line guide to set up GPG-backed signing for Maven Central.

NEVER print the key or passphrase. Only confirm presence.

- [ ] **Step 6: Confirm target-repository credentials**

Detect target by reading the publication's `repositories` block:

```bash
grep -E 'mavenCentral|sonatype|github|nexus' build.gradle.kts | head -10
```

| Target | Credentials check |
|---|---|
| Maven Central via Sonatype | `OSSRH_USERNAME` and `OSSRH_PASSWORD` env vars OR equivalent in `~/.gradle/gradle.properties`. |
| GitHub Packages | `GITHUB_TOKEN` env var. |
| Self-hosted Nexus | per-project; the skill cannot probe — emit INFO. |

- PASS if env vars are present.
- FAIL with a one-line "set $X" hint.

- [ ] **Step 7: Confirm no `-SNAPSHOT` deps in runtimeClasspath**

```bash
./gradlew :<module>:dependencies --configuration runtimeClasspath 2>&1 | grep -F '-SNAPSHOT' | head -20
```

- PASS if zero matches.
- FAIL with the offending deps. Remediation: `/upgrade <lib>` or pin the version in `libs.versions.toml`.

- [ ] **Step 8: Confirm ABI baseline (WARN, not FAIL)**

```bash
[ -d api/ ] || echo "no api/ baseline directory"
grep -lE 'kotlinx\.binary-compatibility-validator|org\.jetbrains\.kotlinx\.binary-compatibility-validator' \
  build.gradle.kts settings.gradle.kts 2>/dev/null
```

- PASS if the plugin is applied AND `api/<module>.api` exists.
- WARN if missing — recommend adding the plugin so future ABI checks have a strong baseline.

- [ ] **Step 9: Compose the report**

Per the `/publish-prep` command's format. Aggregate:

```
BLOCKERS: <count of FAIL>
WARNINGS: <count of WARN>
```

If BLOCKERS > 0: `library-publisher` MUST refuse to publish.
If BLOCKERS == 0: publishable; WARN messages are advisory.

## Output

The markdown report + a JSON summary:

```json
{
  "track":     "library",
  "blockers":  N,
  "warnings":  K,
  "checks": [
    { "name": "coordinates",   "status": "PASS" },
    { "name": "pom-developers", "status": "PASS" },
    { "name": "pom-scm",        "status": "FAIL", "remediation": "..." },
    ...
  ]
}
```

## Notes

- The skill does not run `./gradlew publishToMavenLocal` — even though that would prove publishability, it also pollutes the local cache. Use `library-publisher` for that step deliberately.
- For multi-module projects, run the skill per published module if the project's `publishing` block emits multiple publications.
- Sonatype's "Central Portal" (the new namespace) and the legacy OSSRH have different credential mechanisms. The skill detects which is in use via the publication's repository URL.
