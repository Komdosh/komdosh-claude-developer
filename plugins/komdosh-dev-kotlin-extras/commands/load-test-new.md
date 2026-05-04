# /load-test-new

Scaffold a new Gatling load test module for the service. Pre-flight checks Gatling is in the version catalog before proceeding.

## Steps

- [ ] **Step 1: Pre-flight — check Gatling in version catalog**

```bash
grep -i "gatling" gradle/libs.versions.toml 2>/dev/null || echo "MISSING"
```

If `MISSING`:
"Gatling is not in the version catalog. Invoking `build-expert` to add it."
→ Invoke `build-expert` with: "Add Gatling Kotlin/JVM (io.gatling.gradle plugin and gatling-charts-highcharts dependency) to gradle/libs.versions.toml and create the load-tests module build.gradle.kts."
Wait for build-expert to finish, then continue.

- [ ] **Step 2: Read the service's HTTP surface**

```bash
find . -name "*Controller.kt" -path "*/inbound/*" -not -path "*/build/*" \
  | xargs grep -l "@RestController" 2>/dev/null
```

For each controller found, extract `@RequestMapping` prefixes and `@GetMapping`/`@PostMapping` paths.

- [ ] **Step 3: Load service context**

Run `read-service-context` skill if not already done.

- [ ] **Step 4: Invoke load-test-scaffolder**

Pass to `load-test-scaffolder`:
- Service name and base package
- List of HTTP routes found in Step 2
- Target base URL (ask user: "What is the base URL for load testing? Default: http://localhost:8080")

- [ ] **Step 5: Verify the simulation compiles**

```bash
./gradlew :load-tests:gatlingClasses 2>&1 | tail -10
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 6: Report**

State: simulation class path, scenarios included, how to run:
```bash
./gradlew :load-tests:gatlingRun -DbaseUrl=http://localhost:8080
```
