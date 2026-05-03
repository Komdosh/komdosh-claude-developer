# Persistence Rules

## jOOQ — Type-Safe SQL Only

Never concatenate raw SQL strings. Use the generated jOOQ DSL:

```kotlin
// CORRECT
val order = dsl.selectFrom(ORDERS)
    .where(ORDERS.ID.eq(id.value))
    .awaitFirstOrNull()
    ?.toDomain()

// WRONG — never do this
dsl.execute("SELECT * FROM orders WHERE id = '$id'")
```

Use generated `Tables.*` and `Records.*` from jOOQ codegen. Codegen runs as part of the Gradle build against the Testcontainers database.

## Liquibase — All Schema Changes Go Through Changesets

Filename convention: `V<N>__<past-tense-verb>-<what>.sql` (two underscores).

```
db/changelog/
├── db.changelog-master.yaml
├── V1__create-orders-table.sql
├── V2__add-order-status-index.sql
└── V3__add-customer-email-column.sql
```

Every changeset must be **idempotent** — safe to apply multiple times:

```sql
-- V3__add-customer-email-column.sql
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_email VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_orders_customer_email ON orders (customer_email);
```

Never modify an applied changeset. Add a new one.

Register every new file in `db.changelog-master.yaml`:

```yaml
databaseChangeLog:
  - include:
      file: db/changelog/V3__add-customer-email-column.sql
      relativeToChangelogFile: true
```

## Coroutine-Safe Transactions

Never use `@Transactional` on `suspend fun`. Use `TransactionalOperator`:

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val txOperator: TransactionalOperator
) {
    suspend fun createWithEvent(command: CreateOrderCommand): Order =
        txOperator.executeAndAwait {
            val order = orderRepository.save(Order.from(command))
            outboxRepository.save(OrderCreatedEvent(order.id))
            order
        }
}
```

## Outbox Pattern for Event Publishing

When an event must be published alongside a DB write, write to an outbox table in the **same transaction**. A separate polling adapter reads and publishes. Never publish events in the same transaction scope outside of the outbox table — Kafka/messaging cannot participate in a DB transaction.

## No jOOQ Records Escaping `adapters/outbound/`

jOOQ `Record` types must never appear outside `adapters/outbound/`. Map to domain entities at the adapter boundary:

```kotlin
private fun OrderRecord.toDomain(): Order = Order(
    id = OrderId(this.id),
    customerId = CustomerId(this.customerId),
    status = OrderStatus.valueOf(this.status)
)
```
