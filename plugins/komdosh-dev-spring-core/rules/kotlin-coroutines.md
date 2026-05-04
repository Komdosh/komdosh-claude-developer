# Kotlin Coroutines — 12 Forbidden Patterns

All 12 patterns are enforced conceptually for any code you generate.

| # | Pattern | Why it breaks | Correct alternative |
|---|---|---|---|
| 1 | `runBlocking` in production | Blocks the calling thread; deadlocks under WebFlux event loop | `suspend fun` + structured scope |
| 2 | `runBlocking` in tests | Masks suspension behavior; misses timing issues | `runTest` from `kotlinx-coroutines-test` |
| 3 | `@Transactional` on `suspend fun` | Spring's `@Transactional` is ThreadLocal-bound; the transaction is lost on the first suspension | `TransactionalOperator.transactional()` or a coroutine-aware `@Transactional` equivalent |
| 4 | `ThreadLocal` read/write across suspension points | ThreadLocals are not preserved across dispatcher switches or thread pool hand-offs | Pass values explicitly; use `withContext(coroutineContext)` if needed |
| 5 | `GlobalScope.launch` / `GlobalScope.async` | Unstructured; outlives the request, leaks coroutines | Inject a `CoroutineScope` from the application lifecycle |
| 6 | Blocking I/O without `withContext(Dispatchers.IO)` | Blocks the coroutine dispatcher thread; starves other coroutines | `withContext(Dispatchers.IO) { blockingCall() }` |
| 7 | `withContext` inside `@Transactional` | The transaction is bound to the thread; `withContext` may resume on a different thread, breaking the transaction | Move the `@Transactional` boundary outside or switch to `TransactionalOperator` |
| 8 | Extracting security/trace context inside `withContext` | Context is captured before the switch; Reactor `SecurityContext` and OTel `Context` may not propagate across dispatcher boundaries | Extract all needed values **before** the `withContext` block; pass explicitly |
| 9 | `import java.util.concurrent.locks.ReentrantLock` | JVM monitor held across suspension = undefined behavior | `kotlinx.coroutines.sync.Mutex` |
| 10 | `import java.util.concurrent.CountDownLatch` / `Semaphore` | Blocking synchronization primitives incompatible with coroutines | `Channel`, `StateFlow`, or `Mutex` |
| 11 | `synchronized { ... suspend ... }` | `synchronized` holds a JVM monitor; suspending inside it is undefined behavior | Restructure to avoid holding the monitor across the suspension point |
| 12 | `Thread.sleep(N)` | Blocks the thread; kills throughput | `delay(N)` |

## Correct Patterns

```kotlin
// Blocking I/O: extract context before withContext, wrap call inside
suspend fun findUser(principal: String): User {
    val id = principal  // extracted before switch
    return withContext(Dispatchers.IO) {
        userRepository.findByUsername(id)  // blocking JDBC call
    }
}

// Coroutine test
@Test
fun `should process order`() = runTest {
    val result = orderService.process(CreateOrderCommand("c-1"))
    assertThat(result.status).isEqualTo(OrderStatus.PENDING)
}

// Coroutine-safe mutual exclusion
private val mutex = Mutex()
suspend fun criticalSection() = mutex.withLock { doWork() }
```
