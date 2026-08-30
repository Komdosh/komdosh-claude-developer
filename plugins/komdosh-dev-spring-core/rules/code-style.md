# Code Style

Standard idiomatic Kotlin applies. Local additions only:

- `@JvmInline value class` for every domain identifier — `rules/domain-purity.md`.
- `sealed interface` for result types and discriminated unions, so `when` is exhaustive.
- **No `!!` in production code.** Absence is either a domain error (`?: throw`) or a branch (`?.let`, `?: return`).
- Test classes `<Subject>Test.kt`; test function names in backticks.
- A file past ~300 lines is a signal to split by responsibility.
