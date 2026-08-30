---
description: Find vendor types leaking into application/ and domain/, propose common/ abstractions ranked by impact, and optionally extract one.
argument-hint: "[--extract <target>]"
---

# /audit-leaks

`platform-developer`. Audit mode by default — reports only, changes nothing. `--extract <target>` stages one abstraction.

`read-service-context` first.

The audit reports leaks per vendor package and per file, ranked by (#files × #distinct types), with the suggested `common/` abstraction for each. **Not every leak is an abstraction target** — jOOQ or R2DBC in `application/` means the code is in the wrong layer, and the answer is moving it to `adapters/outbound/`, not wrapping it.

The leak list is a backlog, not a gate. A one-off leak is tech debt with a ticket.

Extraction is a real refactor: it needs an ADR when `common/` doesn't exist yet, it rewrites every call site atomically, and it ends with an ArchUnit rule locking the boundary. Confirm the interface shape with the user before any file is written.
