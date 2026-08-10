# /audit-leaks [--extract <abstraction>]

Audit `application/` and `domain/` for vendor-coupling leaks (Micrometer, jOOQ, Reactor, Jackson, Spring beyond `@Service`/`@Transactional`, Kafka client, R2DBC). Optionally extract one abstraction at a time into a `common/` module.

## Usage

```text
/audit-leaks                          # scan + report only, no code changes
/audit-leaks --extract metrics        # scan, then extract MetricsRegistry into common/observability/
/audit-leaks --extract <area>         # extract a specific abstraction (metrics | time | transaction | messaging | serialization | ids)
```

## Steps

- [ ] **Step 1: Parse arguments**

If the user passed `--extract <abstraction>`, the mode is `extract`; otherwise it's `audit`.

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 3: Invoke `platform-developer`**

Pass the mode and (if extract) the abstraction target. The agent:

- **Audit mode**: scans `application/` and `domain/` for vendor imports, groups by suggested abstraction, prioritises by impact, reports.
- **Extract mode**: runs `check-adr-required` first; if `common/` does not yet exist, requires an ADR via `/adr-new`. Then designs the interface, creates `common/<area>/<Abstraction>.kt`, the concrete adapter in `adapters/outbound/`, wires it in `boot/`, refactors `application/`, and adds an ArchUnit guard.

- [ ] **Step 4: For extract mode — verify**

After the agent reports done:

- Run `module-boundary-check` skill — confirm no leftover vendor imports in `application/`.
- Run `run-verification` skill — full narrowest-first verification.
- Run the new ArchUnit test specifically.

- [ ] **Step 5: Suggest the commit (do not run it)**

Print the agent's suggested commit verbatim. For audit mode, no commit is needed unless the user asks the report be saved to `docs/platform-audit.md`.

For extract mode:

```bash
git add common/ adapters/outbound/<area>/ boot/.../<area>Configuration.kt \
        tests/architecture/<test-class>.kt application/...
git commit -m "refactor(platform): extract <Abstraction> to common/<area>"
```

- [ ] **Step 6: Report**

Print the agent's findings or refactor summary. For audit mode, suggest the next extraction:

> "Highest-impact next step: `/audit-leaks --extract <abstraction>` — affects N files."

For extract mode, suggest verifying with `/service-health` once the commit lands.
