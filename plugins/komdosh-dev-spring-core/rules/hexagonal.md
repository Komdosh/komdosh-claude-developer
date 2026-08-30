# Hexagonal Architecture

## Leaf modules

```
<service>/
├── api/                 Shared contracts consumed by other services — no logic
├── domain/              Pure business logic — zero framework imports
├── application/         Use cases; defines ports in application/ports/
├── adapters/inbound/    HTTP handlers, event consumers
├── adapters/outbound/   DB, producers, HTTP clients — implements output ports
├── boot/                @SpringBootApplication — the only composition root
└── load-tests/          Gatling (sibling, not a child)
```

## Dependency arrows — enforced by ArchUnit in `tests/architecture/`

```
domain  ←  application  ←  adapters/inbound
                        ←  adapters/outbound
                        ←  boot
```

- `domain` depends on nothing. `application` on `domain` only.
- `boot` is the only module that may see every adapter.
- **`adapters/inbound` must never import `adapters/outbound`.** This is the arrow that gets violated in practice — an inbound handler reaching a repository directly bypasses the use case.

Port interfaces live in `application/ports/` and use domain types only in their signatures. Swapping an adapter must not touch `domain/` or `application/`.
