# /analyze-requirements [feature description]

Turn a feature description into a within-service implementation spec at `docs/specs/<feature-slug>.md`. Written inline — the spec's value comes from the conversation's context, which a subagent would not have.

For a spec sourced from the company architecture repository instead of free text, use `/implementation-plan` in `komdosh-dev-spring-delivery`.

## Steps

- [ ] **Step 1: Get the feature description**

If the user provided one, use it. Otherwise ask: "Please describe the feature you want to implement."

- [ ] **Step 2: Load service context**

Run the `read-service-context` skill. Read the existing code in the affected area — the spec must fit the service that exists, not a generic one.

- [ ] **Step 3: Check the system-level gate — stop if it trips**

Does the feature require any of:
- defining a new event contract another service consumes;
- changing an API contract shared with another service;
- adding a new infrastructure dependency (new DB engine, broker, cache)?

If **yes to any**: STOP and tell the user — "This requires a system-level decision outside a single service's scope. Please resolve `<the specific question>` before continuing." Do not design across the boundary on your own.

- [ ] **Step 4: Write the spec**

Save to `docs/specs/<feature-slug>.md` with these sections:

**1. Feature summary** — one paragraph, from the user's perspective.

**2. Scope** — what changes in this service, and what is explicitly *not* in scope and why.

**3. Data shapes** — new/modified domain entities, value classes, DTOs. Flag any schema change for `/add-migration`.

```kotlin
data class OrderItem(
    val productId: ProductId,
    val quantity: Int,
    val unitPrice: Money
) {
    init { require(quantity > 0) { "Quantity must be positive" } }
}
```

**4. Port interfaces** — new/modified interfaces in `application/ports/`.

```kotlin
interface InventoryPort {
    suspend fun checkAvailability(productId: ProductId, quantity: Int): AvailabilityResult
}
```

**5. Edge cases** — at least five, each with the expected behaviour.

| Case | Expected behaviour |
|---|---|
| Customer not found | Return `CustomerNotFound`, 404 at the API layer |

**6. Task breakdown** — ordered tasks, each naming the layer affected and the agent or command that executes it.

**7. Open decisions** — anything unresolved, to be run through the `check-adr-required` skill.

- [ ] **Step 5: Check the open decisions for ADR need**

Run `check-adr-required` on each. If any returns `REQUIRED` or `BORDERLINE`: "This decision may need an ADR — run `/adr-new` before implementation begins."

- [ ] **Step 6: Save, suggest the commit, do not run it**

```bash
mkdir -p docs/specs
```

Print, but do not execute:

```bash
git add docs/specs/<feature-slug>.md
git commit -m "docs: add implementation spec for <feature>"
```

- [ ] **Step 7: Present and confirm**

Present the spec. Ask: "Does this look correct? Should I proceed to implementation, or do you want changes first?" Do not begin implementing until the user confirms.
