# /release-prep [version] [--track=service|library]

Run the full release-readiness pipeline. Detects whether the project is a **service** or a **library**, runs the matching readiness skill, drives version bump + changelog + (rollback playbook | publish prep) in order, and opens the release PR. Stops on any FAIL with the exact remediation command per failing gate.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` skill if it has not run this session. If `service.yaml` declares `kind`, capture it.

- [ ] **Step 2: Invoke `release-coordinator`**

Pass:
- The version argument if supplied (`v1.4.0`).
- The `--track=...` override if supplied.

The agent runs the entire pipeline. It STOPS on any FAIL and prints failing gates with remediation commands.

- [ ] **Step 3: Surface the agent's output**

Print verbatim. The agent already structures the report — do not re-summarise.

- [ ] **Step 4: Suggest follow-ups**

If the agent finished successfully and opened a release PR:
```
Release PR opened: <url>

Next steps:
  1. Review the PR (changelog, version bump, playbook/abi).
  2. Merge when ready.
  3. After merge, push the release tag (the agent printed the exact command).
  4. CI takes over: deploy (service) or publish (library).
```

If the agent stopped on a FAIL:
```
Release blocked at gate <N>: <gate-name>
Remediation: <exact command from the agent's output>

After the fix lands, re-run /release-prep.
```

If the agent stopped because the track was ambiguous:
```
Track ambiguous. Re-run with explicit override:
  /release-prep --track=service     # this is a service that deploys
  /release-prep --track=library     # this is a shared library that publishes
Or add `kind: service|library` to service.yaml to make it stick.
```
