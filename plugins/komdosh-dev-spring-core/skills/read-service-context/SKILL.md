---
name: read-service-context
allowed-tools: Grep, Glob, Read
user-invocable: false
description: Locate service.yaml (or fallback docs/README.md), read module structure, extract package name. Use when session context is not already loaded and you need service metadata before writing code or running commands.
---

# Read Service Context

Orients to a consumer service. **Run once per session** — do not re-run if the context was already emitted.

## 1. Metadata

`service.yaml` / `service.yml` if present — take `name`, `package`, `modules`, and `kind`. Otherwise `docs/README.md`, otherwise discover from the filesystem:

```bash
find . -name "build.gradle.kts" -not -path "*/build/*" -not -path "*/.gradle/*" \
  | sed 's|/build.gradle.kts||;s|^\./||' | sort
```

## 2. Base package

Sample several files and take the most common prefix — **the first file alone is unreliable** (license headers, generated code, jOOQ records):

```bash
find . -name "*.kt" -path "*/main/*" -not -path "*/build/*" -not -path "*/generated/*" \
  | head -5 | xargs grep -h '^package ' | awk '{print $2}' \
  | sort | uniq -c | sort -rn | head -3
```

Take the longest common prefix; ask the user if the results conflict.

## 3. `kind` — the marketplace's single track-detection point

Use `service.yaml`'s `kind` if declared. Otherwise infer:

```bash
# `runApplication<` is the strongest signal — it appears only in Spring Boot apps, and services
# name the file <ServiceName>Application.kt, not literally Application.kt.
# Grep recursively: multi-module repos apply plugins per module, not at the root.
# `|| true` on each pipeline so a no-match doesn't abort under `set -e -o pipefail`.
has_app=$(grep -rl 'runApplication<' --include='*.kt' \
           --exclude-dir=build --exclude-dir=test --exclude-dir='.gradle' . 2>/dev/null | head -1 || true)
has_publish=$(grep -rlE 'maven-publish' --include='build.gradle.kts' \
                --exclude-dir=build --exclude-dir='.gradle' . 2>/dev/null | head -1 || true)

if   [ -n "$has_app" ];     then kind="service"
elif [ -n "$has_publish" ]; then kind="library"
else                             kind="unknown"
fi
```

A Spring Boot plugin match alone is **not** a signal — it is usually applied via a `buildSrc` convention plugin and so absent from the service's own `build.gradle.kts`.

`unknown` never blocks: emit it and let the caller decide. Plenty of repos are neither.

## 4. Emit

```yaml
service:
  name: <name>
  package: <com.example.foo>
  kind: service | library | unknown
  modules: [domain, application, adapters/inbound, adapters/outbound, boot]
  source: service.yaml | docs/README.md | filesystem-discovery
```

If `service.yaml` is missing, say so and suggest creating one with `kind:` set, so downstream consumers don't each re-detect.
