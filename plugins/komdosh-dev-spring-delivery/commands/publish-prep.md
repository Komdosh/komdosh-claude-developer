---
description: Library track — validate coordinates, POM completeness, signing, repository credentials, sources/javadoc jars, and SNAPSHOT cleanliness. Read-only; never publishes.
---

# /publish-prep

**Library track only.** Refuse on the service track.

`read-service-context`, then `check-publish-config`. Report every check as PASS / FAIL / WARN **with the concrete edit that fixes it** — a Gradle snippet for a missing `scm` or `javadocJar`, the env var to set for credentials, the `/upgrade` call for a `-SNAPSHOT` dependency.

**Never print a key, token, or passphrase** — presence only.

Close with the BLOCKER and WARNING counts. Zero blockers → ready; `library-publisher` publishes once `/release-prep` is green. Any blocker → fix and re-run.

**This command never publishes.**
