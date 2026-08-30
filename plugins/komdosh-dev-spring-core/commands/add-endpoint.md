---
description: Add an HTTP endpoint — reads existing controller conventions, wires auth if the route is protected, implements it, and covers it with a WebFluxTest.
argument-hint: "[endpoint description]"
---

# /add-endpoint

Ask for the endpoint (method, path, behaviour, response) if not given.

1. **Read one or two existing `*Controller.kt` under `adapters/inbound/`** for the route prefix, DTO shape, and error pattern actually in use. Mirror them.
2. Ask whether the route requires authentication. If yes, apply `rules/spring-security.md` — including the deny-case test, which is not optional.
3. `backend-implementer` for the handler and service logic.
4. `test-writer` for a `@WebFluxTest` covering success, not-found, and validation failure.
5. `run-verification`.

Report the route, request/response shapes, auth applied, and the test file.
