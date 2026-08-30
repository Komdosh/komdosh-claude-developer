---
description: Evolve an existing Avro schema — classify the change, decide bump-in-place vs version-up, and produce the v(n+1) file when it is breaking.
argument-hint: "<path-to-schema.avsc> [--mode=auto|strict-backward|full]"
---

# /avro-evolve

1. Read the schema and its previous version (`git show HEAD:<path>`, or the latest registered subject). Neither available → this isn't an evolution; use `/avro-new-event`.
2. Run `verify-schema-compat`. Classify per the evolution table in `rules/avro-schemas.md`. `--mode=full` demotes every *borderline* change to breaking.

## Safe-additive → edit in place

Update the `doc` to mention the change, run codegen, confirm the generated class compiles, and re-run `verify-schema-compat`.

## Borderline (BACKWARD only) → edit in place, with a rollout note

Say explicitly that consumers older than this change will not see the new field, and recommend deploying consumers first.

## Breaking → never touch the existing file

Produce `<RecordName>V<n+1>.avsc` alongside it, with the namespace's trailing version bumped, and add the `<aggregate>.<verb>.v<n+1>` constant to `Topics.kt`. **The old schema and topic stay in production until every consumer has migrated.**

The PR description must name: which producers start emitting v(n+1) and when, which consumers must read both versions and for how long, and the retirement date for the old topic. A breaking change without those three is not ready.

Hand off dual-emit to `backend-implementer`, dual-read to `event-consumer-author`, and round-trip plus cross-version tests to `test-writer`.

## Before committing

The `verify-schema-compat` verdict matches your classification · on a breaking change the old file is untouched · `Topics.kt` changed only if a new topic version was introduced · no generated sources committed.
