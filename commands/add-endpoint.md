# /add-endpoint [description]

Add a new HTTP endpoint to the service. Reads existing controller conventions, optionally involves security-expert for protected routes, then invokes backend-implementer and test-writer.

## Steps

- [ ] **Step 1: Get the endpoint description**

If the user provided a description, use it.
If not, ask: "Describe the new endpoint — method, path, what it does, and what it returns."

- [ ] **Step 2: Read existing controllers for conventions**

```bash
find . -name "*Controller.kt" -path "*/inbound/*" -not -path "*/build/*" | head -3
```

Read 1-2 existing controller files to understand:
- Route prefix conventions
- Request/response DTO structure
- Error handling pattern

- [ ] **Step 3: Check authentication requirement**

Ask: "Does this endpoint require authentication? (y/n)"

- [ ] **Step 4: Implement the endpoint**

If protected (user said y):
→ Invoke `security-expert` with the endpoint spec and auth requirements.
  After security-expert defines the security config changes, invoke `backend-implementer` for the handler + service logic.

If unprotected (user said n):
→ Invoke `backend-implementer` with the endpoint spec.

- [ ] **Step 5: Write tests**

→ Invoke `test-writer` with: "Write a `@WebFluxTest` for the new endpoint, covering success case, not-found case, and any validation errors."

- [ ] **Step 6: Run verification**

Run `run-verification` skill.

- [ ] **Step 7: Report**

State: new route registered, request/response shapes, auth applied (if any), test file created.
