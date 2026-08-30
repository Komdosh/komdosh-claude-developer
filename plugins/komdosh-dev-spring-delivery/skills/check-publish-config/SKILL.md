---
name: check-publish-config
user-invocable: false
description: "Library track. Validates Maven coordinates, POM completeness (developers, scm, license, description, url), signing config, target-repository credentials reachability, sources/javadoc jars configured, no -SNAPSHOT deps in runtimeClasspath. Read-only — does not extract keys, does not publish."
---

# Check Publish Config

Library track only. Read-only: it reports gaps with concrete remediation and **never publishes**.

**Never print a key, passphrase, or token.** Every credential check confirms presence only.

**WARN is not FAIL.** A warning informs; only a BLOCKER stops a publish.

## Checks

| # | Check | Verdict |
|---|---|---|
| 1 | Coordinates — reverse-DNS `group`, lowercase-hyphen `name`, a `version` that is neither empty nor Gradle's `unspecified`, and **no `-SNAPSHOT` against a release target** | FAIL |
| 2 | POM `<developers>` with a name **and** email, `<scm>` with connection and URL, `<licenses>` with a recognised SPDX id, non-trivial `<description>`, `<url>` | FAIL per missing element, with the Gradle snippet that adds it. A non-SPDX licence is a WARN, not a FAIL |
| 3 | A `sourcesJar` task, and a `javadocJar`/`dokkaJavadocJar` **wired into the publication** — a task that exists but isn't wired publishes nothing | FAIL |
| 4 | Signing configured, in either the in-memory env form or `signing.gnupg.*` properties | FAIL |
| 5 | Credentials for the detected target — Sonatype/OSSRH, GitHub Packages, or a self-hosted Nexus (which cannot be probed: **INFO, not FAIL**) | FAIL |
| 6 | **No `-SNAPSHOT` in the resolved `runtimeClasspath`** — remediation is `/upgrade <lib>` or pinning in the catalog | FAIL |
| 7 | `kotlinx.binary-compatibility-validator` applied with a committed `api/` baseline | **WARN** — its absence weakens future ABI checks but does not block this publish |

Generate the POM (`generatePomFileForMavenPublication`) and read it rather than inferring from the build script — what ships is the generated POM.

## Output

The per-check report plus JSON — `blockers`, `warnings`, and a `checks` array of `{name, status, remediation}`.

**Any BLOCKER means `library-publisher` must refuse to publish.** Zero BLOCKERs means publishable, warnings advisory.
