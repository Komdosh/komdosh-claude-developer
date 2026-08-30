---
description: Service track — classify each migration in the release window as reversible or forward-fix-only, emit the inverse SQL where possible, and name the flags that must move with the rollback.
argument-hint: "[version]"
---

# /rollback-playbook

**Service track only.** Refuse on the library track — a library doesn't roll back, it ships a fix version. Ambiguous track → ask for `kind:` in `service.yaml` or `--track=service`.

1. Window is `last_tag..<version>`, else `last_tag..HEAD`. Collect the changesets **added** in it.
2. `produce-rollback-playbook` → `docs/release/playbooks/<version>.md`.
3. Surface, prominently: **how many changesets are forward-fix only**, and **the ENV vars and feature flags that must move atomically with the rollback**. A reverted deploy with its flag still on behaves like neither version, and that is the detail that gets missed at 3am.

The playbook assumes no backup is available — that is the situation it exists for.
