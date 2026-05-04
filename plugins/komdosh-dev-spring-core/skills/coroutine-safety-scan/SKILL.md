---
name: coroutine-safety-scan
description: Grep-based scan for the 12 forbidden coroutine patterns from rules/kotlin-coroutines.md across touched Kotlin files. Run before declaring a code change done — catches runBlocking, Thread.sleep, @Transactional on suspend fun, withContext inside @Transactional, MDC across suspension, GlobalScope, blocking JVM primitives, and more, in seconds. Cheaper than waiting for run-verification or detekt.
---

# Coroutine Safety Scan

## When to Use

Run after editing any Kotlin file under `src/main/kotlin/` or `src/test/kotlin/`, **before** invoking `run-verification`. Treat as mandatory for changes in `application/`, `adapters/inbound/`, `adapters/outbound/`. Optional but recommended for tests (the rules forbid `runBlocking` there too).

This skill enforces [`rules/kotlin-coroutines.md`](../../rules/kotlin-coroutines.md) — read that file for the rationale behind each pattern.

## Output

For each violation found:

```
[<rule-id>] <severity> <file>:<line>
  <one-line excerpt of the offending code>
  Fix: <one-line corrected pattern from rules/kotlin-coroutines.md>
```

Then a summary line:

```
Coroutine safety: <CLEAN | N violations (<P> blockers, <Q> warnings)>
```

A BLOCKER means the code WILL break in production. A WARNING means it may break under specific conditions. Treat both as must-fix before commit unless the calling agent has a written reason to accept the risk.

## Steps

- [ ] **Step 1: Determine scope**

If the calling agent supplied a list of touched files, scan those. Otherwise, scan files modified relative to the merge base:

```bash
git merge-base HEAD origin/main 2>/dev/null \
  | xargs -I{} git diff --name-only {}..HEAD -- '*.kt' \
  | xargs -I{} sh -c '[ -f "$1" ] && echo "$1"' _ {}
```

Skip generated code (`*/build/generated/*`, `*/build/classes/*`).

- [ ] **Step 2: Apply the 12 pattern checks**

Run each grep below against the file list. The grep tag in `[brackets]` is the rule id used in the report.

```bash
files=( <list from Step 1> )

# [CR-1] runBlocking in production code (anywhere outside of tests + main())
grep -nE '\brunBlocking\b' "${files[@]}" \
  | grep -v -E 'src/test/|/main\.kt:|fun main\b'

# [CR-2] runBlocking in test code
grep -nE '\brunBlocking\b' "${files[@]}" \
  | grep -E 'src/test/'

# [CR-3] @Transactional on suspend fun (search for the two lines together)
grep -nE 'suspend fun' "${files[@]}" -B1 \
  | grep -B1 'suspend fun' \
  | grep -E '@Transactional'

# [CR-4] ThreadLocal use in code that may suspend
grep -nE '\bThreadLocal<' "${files[@]}"

# [CR-5] GlobalScope.{launch,async}
grep -nE '\bGlobalScope\.(launch|async)\b' "${files[@]}"

# [CR-6] Blocking I/O without withContext(Dispatchers.IO)  — heuristic:
# JDBC / Files.read* / InputStream.read calls in a function NOT wrapped by withContext
grep -nE '\b(jdbcTemplate|FileInputStream|FileOutputStream|Files\.(read|write)|java\.net\.HttpURLConnection)\b' "${files[@]}" \
  | grep -v -E 'withContext\(Dispatchers\.IO'

# [CR-7] withContext inside @Transactional (rough heuristic — flag both for human review)
grep -nE '@Transactional' "${files[@]}" -A20 \
  | grep -E 'withContext\('

# [CR-8] Reading SecurityContext / OTel Context inside withContext block
grep -nE 'withContext\(' "${files[@]}" -A10 \
  | grep -E 'ReactiveSecurityContextHolder|Context\.current\(\)|OpenTelemetry\.get'

# [CR-9] java.util.concurrent.locks.ReentrantLock
grep -nE 'java\.util\.concurrent\.locks\.ReentrantLock|\bReentrantLock\(' "${files[@]}"

# [CR-10] CountDownLatch / Semaphore (the JDK ones, not kotlinx)
grep -nE 'java\.util\.concurrent\.(CountDownLatch|Semaphore)' "${files[@]}"

# [CR-11] synchronized(...) blocks containing await/yield/withContext (forbidden — undefined behaviour)
grep -nE 'synchronized\(' "${files[@]}" -A10 \
  | grep -E '\.(await|awaitSingle|awaitFirstOrNull)|withContext\(|delay\('

# [CR-12] Thread.sleep
grep -nE '\bThread\.sleep\(' "${files[@]}"
```

- [ ] **Step 3: Map violations to severity**

| Rule | Severity | Why |
|---|---|---|
| CR-1, CR-3, CR-7, CR-8, CR-9, CR-11 | BLOCKER | Will break under load, undefined behaviour, or silently corrupt transactions |
| CR-2, CR-5, CR-6, CR-10, CR-12 | BLOCKER | Will deadlock or starve the dispatcher |
| CR-4 | WARNING | ThreadLocal in a suspending context is *usually* wrong — check whether the code can suspend on this path |

CR-7 and CR-8 are heuristics; surface them but tag them `WARNING (review)` so the human confirms before treating as a defect.

- [ ] **Step 4: Report**

Emit one line per violation per the format in the Output section. Then the summary line.

If `CLEAN`, state the file count scanned: `Coroutine safety: CLEAN (<N> files scanned).`

- [ ] **Step 5: When violations exist**

Do NOT auto-fix. Hand control back to the calling agent (typically `backend-implementer` or `cleanuper`) with:

```
Coroutine safety scan blocked the change. Fix the violations above, then re-run this skill.
Refer to rules/kotlin-coroutines.md for the corrected patterns.
```

## Notes

- This skill is grep-based by design — it's *fast* and runs before the much-slower `run-verification`. False positives are acceptable (treat as "review"); false negatives matter more.
- For CR-6 (blocking I/O without `withContext`), the grep is heuristic. Add project-specific blocking calls to the pattern as the team encounters them.
- This skill is complementary to `detekt` (which catches a different overlapping set). Both are recommended; this one runs in seconds and gives you per-line feedback in the conversation, where detekt runs in tens of seconds and gives you HTML reports.
