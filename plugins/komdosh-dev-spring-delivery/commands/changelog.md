---
description: Generate or update the CHANGELOG.md section for the next release from Conventional Commits since the last tag.
argument-hint: "[version]"
---

# /changelog

Same on both tracks.

1. Target version from the argument, else the project's declared version, else ask.
2. Run `write-changelog`. It locates the last tag (falling back to the root commit **and saying so**), groups commits into the Keep-a-Changelog sections, optionally enriches terse subjects via `reveal-knowledge` when revealer is installed, and updates or creates `CHANGELOG.md`.
   **Every entry traces to a real commit** — the skill invents nothing and never rewrites a prior section.
3. Show the new section plus the per-section counts and skipped-commit count.
4. Print the commit commands; do not run them.

**If the section contains breaking changes that no commit marked with `!` or a `BREAKING CHANGE:` footer, alert the user** — the version they are about to cut is probably wrong, and `/version-bump` should be reconciled first.
