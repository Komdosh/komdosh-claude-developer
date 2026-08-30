---
name: produce-rollback-playbook
user-invocable: false
description: "Service track. For each Liquibase changeset added in the release window, classify rollback as mechanically reversible / forward-fix only / type-narrowing, emit inverse SQL where possible, and surface ENV vars and feature flags that must move atomically with rollback. Writes docs/release/playbooks/<version>.md. Read-only on source; writes one doc."
---

# Produce Rollback Playbook

Service track only — refuse on the library track. The output is what the on-call engineer reads at 3am, so it assumes **no backup is available**: the strategy has to work without one.

Read-only on source; runs no migration; writes one document.

## Per changeset added since the last tag

Classify, and emit accordingly:

| Class | Examples | Output |
|---|---|---|
| **Mechanically reversible** | add nullable column, create index, add deferrable constraint | The inverse DDL, ready to run |
| **Forward-fix only** | drop column/table, any destructive change | **State it plainly with the rationale, and sketch the corrective migration.** Never fabricate an inverse — a reverse `ADD COLUMN` does not bring the data back, and printing one invites someone to believe it did |
| **Type-narrowing / NOT NULL tightening** | set NOT NULL after a backfill | Forward-fix only: the backfill ran under the old code, so a rollback must re-widen first |

## Also surface

**The ENV vars and feature flags that must move atomically with the rollback.** A reverted deploy with its flag still on is a half-rollback that behaves like neither version — this is the part that gets forgotten under pressure, so it goes near the top of the document, not in an appendix.

## Output

`docs/release/playbooks/<version>.md` — per changeset: the file, the class, the inverse SQL or the forward-fix sketch, and its ordering constraint relative to the deploy. Then the flag/ENV block, and a one-line summary of how many changesets are forward-fix only.
