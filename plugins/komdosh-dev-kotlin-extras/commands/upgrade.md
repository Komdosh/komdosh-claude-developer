---
description: Bump one library in the version catalog — changelog read, breaking changes mapped to local files, verified, with compile fixes capped at 5 iterations.
argument-hint: "<library|alias|CVE-id> [target-version]"
---

# /upgrade

`dependency-upgrader`, one library per run.

Pass the coordinate, catalog alias, or CVE id, plus any target version. **A major bump stops for your confirmation** before anything is edited.

The agent reports the changelog's breaking changes **mapped to the file globs they affect in this project**, the verification result, and the suggested commit — which it prints and never runs.

If it hits the 5-iteration fix cap, the remaining compile errors go to `backend-implementer`; the bump is bigger than a maintenance task.
