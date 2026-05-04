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

If found: extract `name`, `package`, and `modules` from the file. Proceed to Step 4.

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

- [ ] **Step 5: Summarize findings**

State in one paragraph:
- Service name
- Base Java package
- Module list (from discovery)
- Any gaps (e.g., no service.yaml found — suggest creating one)

Use this summary to inform all subsequent actions in the session.
