# CLAUDE.md — komdosh-dev-spring-events

This plugin adds Kafka/SQS/RabbitMQ consumer authoring on top of `komdosh-dev-spring-core`.

## What it adds

- Agent: [`event-consumer-author`](agents/event-consumer-author.md) — writes Kafka/SQS/RabbitMQ consumers per `rules/event-consumers.md`. Manual offset/ack, mandatory idempotency via a `processed_events` table, transient-vs-poison error policy with DLQ routing, schema-registry DTOs. Hands off to `migration-writer` (in core) for the dedupe-table changeset and to `test-writer` (in core) for happy-path/redelivery/poison tests.
- Rule: [`event-consumers.md`](rules/event-consumers.md) — topic / queue naming, manual offset/ack policy per broker, mandatory idempotency, transient-vs-poison error policy, schema-registry DTOs, the one permitted `runBlocking` at the framework-owned listener-thread boundary, observability metrics, Testcontainers tests, 8 forbidden patterns.

## Dependencies

This plugin requires `komdosh-dev-spring-core` to be installed in the same project. The agent delegates to `migration-writer` (core) for the `processed_events` table migration and to `test-writer` (core) for the test cases. The foundational rules (hexagonal, kotlin-coroutines, spring-webflux, persistence, observability) are loaded by core.

@rules/event-consumers.md
