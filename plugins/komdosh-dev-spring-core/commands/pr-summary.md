---
description: Produce a PR/MR description from the current git state, with the matching gh/glab command or a body to paste.
---

# /pr-summary

1. Gather `git status`, `git log <base>..HEAD --oneline`, `git diff <base>..HEAD --stat`; fall back to `@{upstream}..HEAD` when the base yields nothing.
2. Read the diff for context.
3. Detect the platform from `git remote get-url origin`: `github.com` → `gh pr create` · `gitlab` → `glab mr create` · otherwise supply the body to paste.
4. Body — **What** (specific bullets, never "updated code") · **Why** (the motivation in a sentence or two) · **How** (only the implementation decisions a reviewer actually needs, e.g. "uses `TransactionalOperator` because the method is a `suspend fun`") · **Test Plan** (what unit, integration, and manual checks cover).
5. Output the ready command with the body in a heredoc, or the paste instructions. **Do not run it.**
