---
name: read-service-context
description: Locate service.yaml (or fallback docs/README.md), read module structure, extract package name. Use when session context is not already loaded and you need service metadata before writing code or running commands.
---

# Read Service Context

## When to Use

Use this skill when:
- You need the service name, base package, or module layout before writing code.
- You're starting a fresh sub-task and need to orient yourself.

Do NOT re-run this skill if service context was already emitted in the current session.

## Steps

- [ ] **Step 1: Check for service.yaml**

```bash
if [[ -f service.yaml ]]; then cat service.yaml; elif [[ -f service.yml ]]; then cat service.yml; fi
```

If found: extract `name`, `package`, `modules`, and **`kind`** (optional — `service` or `library`) from the file. Proceed to Step 4.

- [ ] **Step 2: Fallback — check docs/README.md**

```bash
[[ -f docs/README.md ]] && head -80 docs/README.md
```

If found: read the service name and package from the README header.

- [ ] **Step 3: Discover module structure from filesystem**

```bash
find . -name "build.gradle.kts" \
  -not -path "*/build/*" \
  -not -path "*/.gradle/*" \
  | sed 's|/build.gradle.kts||' \
  | sed 's|^\./||' \
  | sort
```

- [ ] **Step 4: Extract base package name**

Read up to 5 candidate files and pick the most common package prefix — relying on the *first* file is fragile (license headers, generated code, jOOQ records, etc.):

```bash
find . -name "*.kt" -path "*/main/*" \
  -not -path "*/build/*" -not -path "*/generated/*" \
  | head -5 \
  | xargs grep -h '^package ' 2>/dev/null \
  | awk '{print $2}' \
  | sort | uniq -c | sort -rn | head -3
```

Take the longest common prefix of the listed packages as the service's base package. If results conflict, ask the user.

- [ ] **Step 5: Determine `kind` (service | library)**

If `service.yaml` declared `kind`, use it. Otherwise infer from build:

```bash
has_publish=$(grep -lE 'maven-publish|`maven-publish`' build.gradle.kts settings.gradle.kts 2>/dev/null | head -1)
has_boot=$(grep -lE 'org\.springframework\.boot|spring-boot' build.gradle.kts settings.gradle.kts 2>/dev/null | head -1)
has_app=$(find . -name 'Application.kt' -not -path '*/build/*' -not -path '*/test/*' \
           -exec grep -lE 'runApplication<' {} + 2>/dev/null | head -1)
has_dockerfile=$(find . -maxdepth 3 -name 'Dockerfile' | head -1)

if   [ -n "$has_publish" ] && [ -z "$has_boot" ] && [ -z "$has_app" ]; then kind="library"
elif [ -n "$has_boot" ] && [ -n "$has_app" ] && [ -n "$has_dockerfile" ]; then kind="service"
elif [ -n "$has_boot" ] && [ -n "$has_app" ]; then kind="service"   # boot app without Dockerfile is still a service
else kind="unknown"
fi
```

If `kind == unknown`, do NOT block — emit `unknown` and let the caller decide whether to ask the user. Many internal tools and code samples are neither service nor library and don't need the field.

- [ ] **Step 6: Summarize findings**

State in one paragraph:
- Service name
- Base Java package
- `kind` — service | library | unknown
- Module list (from discovery)
- Any gaps (e.g., no service.yaml found — suggest creating one with `kind:` set so the release plugin and other consumers don't have to re-detect)

Use this summary to inform all subsequent actions in the session.

### Output schema

The skill emits a single block other skills/agents can parse:

```yaml
service:
  name: <name>
  package: <com.example.foo>
  kind: service | library | unknown
  modules: [domain, application, adapters/inbound, adapters/outbound, boot]
  source: service.yaml | docs/README.md | filesystem-discovery
```
