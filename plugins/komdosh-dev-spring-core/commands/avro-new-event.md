---
description: Add an Avro-backed event end-to-end — detect toolchain, author the schema, verify codegen, and hand off the registry-subject step.
argument-hint: "<EventName> [--direction=inbound|outbound] [--topic=<name>]"
---

# /avro-new-event

Stops at "schema committed, codegen runs". Consumer/producer wiring is a separate hand-off.

1. `read-service-context` for the base package and module layout.
2. `discover-avro-toolchain`:
   - Toolchain present → continue.
   - **Nothing configured** → ask the user to approve `com.github.davidmc24.gradle.plugin.avro` plus the registry SDK matching their broker config. **Delegate the Gradle edit to `rules/gradle-build.md` — do not edit `build.gradle.kts` here.**
   - Plugin but no registry → continue with local codegen and record the skipped registry configuration in the PR.
3. Confirm direction (producer vs consumer) — it picks the module: `adapters/inbound/<consumer>/src/main/avro/…` or `adapters/outbound/<channel>/src/main/avro/…`. Derive the topic per `rules/event-consumers.md`: `OrderCreated` → `orders.created.v1`.
4. `avro-schema-author` writes the `.avsc`.
5. Verify codegen produces the class:

```bash
./gradlew :<module>:generateAvroJava --rerun-tasks
find . -path '*/build/generated-main-avro-java/*' -name '<EventName>V1.java'
```

   **On a codegen failure, surface the Avro compiler error verbatim and stop.** Never "fix" it by stripping `doc` fields or relaxing types — route back to `avro-schema-author` with the error.
6. **Surface the registration command; never run it.** Registration is a deployment action. Subject is `<topic>-value` under the default `TopicNameStrategy`; only suggest another strategy if the project's existing subjects already use one.
7. Name the next step — `event-consumer-author` for a new inbound consumer, `test-writer` for a redelivery test on an existing one, `backend-implementer` for an outbound outbox publisher.

Schema, `Topics.kt` constant, and changelog land in one commit. **Generated sources are never committed.**
