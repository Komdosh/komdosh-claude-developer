# /upgrade [library-or-alias-or-cve] [target-version]

Bump a single dependency in `gradle/libs.versions.toml`, run verification, and report. Always one library at a time — never bulk.

## Steps

- [ ] **Step 1: Get the target**

If the user provided a library coordinate, alias, or CVE id, use it.

If not, ask: "Which library should I upgrade? (give me a coordinate like `org.springframework.boot:spring-boot-starter-webflux`, a `libs.versions.toml` alias like `spring-boot`, or a CVE id like `CVE-2024-12345`)"

- [ ] **Step 2: Load service context**

Run `read-service-context` skill if it has not run this session.

- [ ] **Step 3: Invoke `dependency-upgrader`**

Pass the library identifier and any target version the user supplied. The agent:

1. Locates the dependency in `gradle/libs.versions.toml`.
2. Determines current and target versions; flags major bumps for confirmation.
3. Reads the changelog and lists breaking changes with affected file globs.
4. Applies the bump.
5. Runs verification narrowest-first; iterates on compile fixes only (max 5 attempts).
6. Reports outcome.

- [ ] **Step 4: Suggest the commit (do not run it)**

Print, but do not execute, what the agent emitted in its report — typically:

```bash
git add gradle/libs.versions.toml <any-source-files-touched>
git commit -m "chore(deps): bump <alias> from <current> to <target>"
```

If the bump introduced a meaningful behaviour change, suggest also drafting an ADR via `/adr-new`.

- [ ] **Step 5: Report**

Print the agent's verification status and notable changelog items. Suggest follow-ups if appropriate:

- Verification FAILED with non-compile errors → "Hand off to `backend-implementer` for behavioural fixes."
- Major bump → "Consider `/adr-new` for the architectural impact."
- Other CVEs flagged in the changelog → "Run `/upgrade <next-lib>` after this lands."
