# /avro-new-event &lt;EventName&gt; [--direction=inbound|outbound] [--topic=&lt;name&gt;]

Add a new Avro-backed event end-to-end: detect toolchain → author the schema → verify codegen → produce the registry-subject hand-off. Stops at "schema committed, codegen runs"; consumer/producer wiring is delegated to the events plugin or `backend-implementer`.

## Steps

- [ ] **Step 1: Load service context**

Run `read-service-context` if it has not run this session. Capture the base package and module layout — schemas live alongside the adapter that owns the channel, never under `domain/` or `application/`.

- [ ] **Step 2: Detect the toolchain**

Run [`discover-avro-toolchain`](../skills/discover-avro-toolchain/SKILL.md). Three outcomes:

- **Toolchain present** (davidmc24 / Confluent / avro4k) → continue.
- **No Avro plugin, no registry SDK** → ask the user to approve adding `com.github.davidmc24.gradle.plugin.avro` (default) and `io.confluent:kafka-avro-serializer` (or Apicurio equivalent if the project's broker config points at Apicurio). The Gradle edit itself is delegated to `rules/gradle-build.md` — do NOT edit `build.gradle.kts` from this command. Resume once the build is green.
- **Plugin present but no registry** → continue with local codegen only; surface that registry-subject configuration is skipped and document the gap in the PR description.

- [ ] **Step 3: Confirm direction and topic**

If `--direction` was not supplied, ask the user: "Is this service the **producer** of `<EventName>` or the **consumer**?" Default to consumer if the service has more inbound adapters than outbound. The direction picks the module:

- `inbound` → schema in `adapters/inbound/<consumer>/src/main/avro/...`
- `outbound` → schema in `adapters/outbound/<channel>/src/main/avro/...`

If `--topic` was not supplied, derive it from the event name per [events plugin naming](../../komdosh-dev-spring-core/rules/event-consumers.md#topic--queue-naming): `<aggregate>.<past-tense-verb>.v1` (e.g. `OrderCreated` → `orders.created.v1`).

- [ ] **Step 4: Invoke `avro-schema-author`**

Pass `EventName`, direction, topic, and the toolchain verdict. The agent writes the `.avsc`, picks the namespace (Kotlin package of the owning module + `.events.v1`), enforces all of `rules/avro-schemas.md`.

- [ ] **Step 5: Verify codegen**

```bash
./gradlew :<module-path>:generateAvroJava --rerun-tasks
find . -path '*/build/generated-main-avro-java/*' -name '<EventName>V1.java'
```

The generated class must exist. If codegen fails, surface the Avro compiler error verbatim and stop — do not "fix" the schema by stripping `doc` fields or relaxing types; route back to `avro-schema-author` with the error.

- [ ] **Step 6: Schema Registry hand-off**

If a registry SDK is on the classpath, surface (do NOT execute) the registration step in a PR-ready snippet:

- **Confluent gradle-schema-registry-plugin**: `./gradlew registerSchemas` (or `testSchemasTask` first to verify compatibility against the existing subject).
- **Apicurio**: `apicurio-registry-cli register --registry-url $REGISTRY_URL --artifact-id <topic>-value --type AVRO ./<path>/<EventName>V1.avsc`.

Subject name follows the `TopicNameStrategy` (default): `<topic>-value` (e.g. `orders.created.v1-value`). Other strategies (`RecordNameStrategy`, `TopicRecordNameStrategy`) are documented in [`rules/avro-registry.md`](../rules/avro-registry.md) — only suggest those if the project's existing subjects already use them.

Registration runs at deploy time, not from the developer's laptop in production. Local dev may register against a Testcontainers / docker-compose registry.

- [ ] **Step 7: Suggest the next step**

- **Inbound, consumer doesn't exist yet** → "Run `event-consumer-author` (from komdosh-dev-spring-core) to write the consumer for `<topic>`. The DTO is generated; the consumer agent will reference it directly."
- **Inbound, consumer already exists** → "Update the existing consumer in `adapters/inbound/<consumer>/` to deserialize into the new generated class. Run `test-writer` to add a redelivery test for the new event."
- **Outbound** → "Run `backend-implementer` to wire the outbox publisher for `<topic>`. The producer reads `total_amount` (or whichever field) from the domain entity and emits `<EventName>V1`."

- [ ] **Step 8: Commit**

The schema, the topic constant in `Topics.kt` (if creating a new one), and any changelog entry land in a single commit titled `feat(events): add <EventName>V1 schema`. Generated sources are NOT committed.
