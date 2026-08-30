# Kotlin Coroutines — 12 Forbidden Patterns

Enforced for any code generated or reviewed. `coroutine-safety-scan` greps these.

| # | Pattern | Correct alternative |
|---|---|---|
| 1 | `runBlocking` in production | `suspend fun` + structured scope |
| 2 | `runBlocking` in tests | `runTest` (`kotlinx-coroutines-test`) |
| 3 | `@Transactional` on `suspend fun` | `TransactionalOperator.executeAndAwait` — Spring's `@Transactional` is ThreadLocal-bound and the transaction is **lost at the first suspension**, silently |
| 4 | `ThreadLocal` read/write across a suspension point | Pass values explicitly — ThreadLocals do not survive a dispatcher switch |
| 5 | `GlobalScope.launch` / `async` | Inject a lifecycle-owned `CoroutineScope` |
| 6 | Blocking I/O without `withContext(Dispatchers.IO)` | Wrap the blocking call |
| 7 | `withContext` inside `@Transactional` | Move the transaction boundary out, or use `TransactionalOperator` — the resumed thread is not the transaction's thread |
| 8 | Reading security/trace context **inside** `withContext` | Extract before the switch and pass explicitly — Reactor `SecurityContext` and OTel `Context` do not cross the boundary, so this yields null or the wrong principal and passes every happy-path test |
| 9 | `ReentrantLock` | `kotlinx.coroutines.sync.Mutex` |
| 10 | `CountDownLatch` / `Semaphore` (`java.util.concurrent`) | `Channel`, `StateFlow`, `Mutex` |
| 11 | Suspending inside `synchronized { }` | Restructure — a JVM monitor held across a suspension is undefined behaviour |
| 12 | `Thread.sleep` | `delay` |

Patterns 3, 4, 7, and 8 are the expensive ones: the code compiles, tests pass, and the defect only appears under concurrency or in production.
