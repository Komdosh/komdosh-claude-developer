---
name: coroutine-safety-scan
allowed-tools: Grep, Glob, Read
description: Grep-based scan for the 12 forbidden coroutine patterns from rules/kotlin-coroutines.md across touched Kotlin files. Run before declaring a code change done — catches runBlocking, Thread.sleep, @Transactional on suspend fun, withContext inside @Transactional, MDC across suspension, GlobalScope, blocking JVM primitives, and more, in seconds. Cheaper than waiting for run-verification or detekt.
---

# Coroutine Safety Scan

Enforces `rules/kotlin-coroutines.md`. Mandatory after editing anything under `application/` or `adapters/`, **before** `run-verification`. Seconds, not minutes — false positives are acceptable, false negatives are not.

## 1. Scope

Use the caller's touched-file list if given; otherwise diff against the merge base, `*.kt` only, skipping `*/build/*`.

```bash
git merge-base HEAD origin/main 2>/dev/null \
  | xargs -I{} git diff --name-only {}..HEAD -- '*.kt' \
  | grep -v '/build/' || true
```

## 2. Patterns

```bash
files=( <list from step 1> )

# [CR-1] runBlocking in production — allowed ONLY at a framework-owned listener
#        boundary (rules/event-consumers.md); such sites carry an "// Allowed:" comment.
grep -nE '\brunBlocking\b' "${files[@]}" | grep -v -E 'src/test/|fun main\b'
# [CR-2] runBlocking in tests
grep -nE '\brunBlocking\b' "${files[@]}" | grep -E 'src/test/'
# [CR-3] @Transactional on a suspend fun
grep -nE -A1 '@Transactional' "${files[@]}" | grep -E 'suspend fun'
# [CR-4] ThreadLocal in code that can suspend
grep -nE '\bThreadLocal<' "${files[@]}"
# [CR-5] GlobalScope
grep -nE '\bGlobalScope\.(launch|async)\b' "${files[@]}"
# [CR-6] blocking I/O not wrapped in withContext(Dispatchers.IO)
grep -nE '\b(jdbcTemplate|FileInputStream|FileOutputStream|Files\.(read|write)|HttpURLConnection)\b' "${files[@]}" \
  | grep -v 'withContext(Dispatchers.IO'
# [CR-7] withContext inside @Transactional
grep -nE -A20 '@Transactional' "${files[@]}" | grep -E 'withContext\('
# [CR-8] security/trace context read inside withContext
grep -nE -A10 'withContext\(' "${files[@]}" | grep -E 'ReactiveSecurityContextHolder|Context\.current\(\)|OpenTelemetry\.get'
# [CR-9] ReentrantLock
grep -nE 'ReentrantLock' "${files[@]}"
# [CR-10] JDK CountDownLatch / Semaphore
grep -nE 'java\.util\.concurrent\.(CountDownLatch|Semaphore)' "${files[@]}"
# [CR-11] suspension inside synchronized
grep -nE -A10 'synchronized\(' "${files[@]}" | grep -E '\.await|withContext\(|delay\('
# [CR-12] Thread.sleep
grep -nE '\bThread\.sleep\(' "${files[@]}"
```

## 3. Severity

All BLOCKER except **CR-4 (WARNING** — ThreadLocal is only wrong if that path can actually suspend) and **CR-7 / CR-8, which are line-proximity heuristics** — report them as `WARNING (review)` so a human confirms before treating them as defects.

## 4. Report

One line per violation: `[CR-n] SEVERITY file:line` + the offending excerpt + the corrected pattern. Then `Coroutine safety: CLEAN (N files scanned)` or the violation counts.

**Never auto-fix** — hand back to the calling agent with the rule reference.
