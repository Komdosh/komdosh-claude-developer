---
description: Work through failing tests one class at a time — hypothesis first, minimal fix, confirmed green before moving on.
---

# /test-fix

1. `./gradlew test` and list failures grouped by module. None → say so and stop.
2. Take the **first** failing class and run it in isolation with `--info`, reading the whole stack trace.
3. **State the hypothesis before editing** — one sentence — and say whether the bug is in the test or in production code.
4. Make the minimal fix for that failure only. No refactoring of surrounding code. Complex production changes go to `backend-implementer`.
5. Re-run the class in isolation. Still failing → revisit the hypothesis; **do not move on**.
6. Confirm green, then repeat.

Never fix several classes in one edit, never change an assertion to match wrong production behaviour, and never `@Disabled` a test without explicit user approval.
