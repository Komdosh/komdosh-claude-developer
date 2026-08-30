---
description: Library track — mark a public symbol @Deprecated with a replacement and sunset version, list remaining internal call-sites, and add the changelog breadcrumb.
argument-hint: "<fully-qualified-symbol> [--sunset=vX.Y.Z]"
---

# /deprecate-api

**Library track only.** `library-publisher --mode=deprecate`.

Ask for the symbol if not given; ask to disambiguate on multiple matches.

Sunset defaults to **current minor + 2**, overridable. `replaceWith` is **mandatory when a successor exists**. The annotation lands at `level = WARNING` with the sunset version **inside the message**, not only in the changelog.

The report must list **every internal call-site still using the symbol** — a library that deprecates something it still calls itself has not finished the job.

Ends with `produce-abi-report` confirming the change classifies as `deprecated`, not `breaking`. If it comes back breaking, stop: the annotation changed the ABI in a way that was not intended.
