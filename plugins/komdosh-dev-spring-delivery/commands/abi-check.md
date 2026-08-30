---
description: Library track — diff the public API surface against the last released tag and classify every symbol as added, deprecated, changed-signature, or removed.
argument-hint: "[base-tag]"
---

# /abi-check

**Library track only.** Refuse on the service track — a service's equivalent surface is its HTTP and event contracts.

1. `read-service-context` to confirm the track.
2. Base = the supplied tag, else the newest non-pre-release tag.
3. `produce-abi-report`, which prefers `kotlinx.binary-compatibility-validator` baselines and falls back to japicmp.
4. Report to `docs/release/abi-v<version>.md`: per-class symbol lists, and for each breaking delta the **before/after signature plus what callers must do** — a list of names without the migration is not actionable.

Counts, recommended bump, and the note that **`/version-bump` will refuse a lesser bump when breaking deltas exist**.

When the validator isn't configured, say so explicitly: japicmp still works, but a committed `api/` baseline is the stronger long-term source of truth, and `/publish-prep` warns until it exists.
