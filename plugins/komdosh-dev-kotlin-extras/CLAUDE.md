# komdosh-dev-kotlin-extras

Niche tooling on top of `komdosh-dev-spring-core`. Install only if you need one of these.

`/upgrade` bumps **one** library at a time · `/detect-flakes` classifies non-deterministic tests with evidence · `/load-test-new` scaffolds Gatling simulations.

None of them finishes the job alone: the upgrader hands application-code refactoring to `backend-implementer`, and the flake detector hands coroutine-timing flakes to `test-writer` and container-readiness flakes to `integration-debugger`. **They surface and classify; the specialists fix.**
