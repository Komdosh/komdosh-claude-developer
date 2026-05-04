---
name: match-routes-to-filters
description: "Builds a coverage matrix of every @RestController handler vs the project's SecurityWebFilterChain rules. Classifies each handler as authenticated / permit-all-by-rule / unmatched / shadowed. Surfaces the file:line for both the handler and the filter rule that matched (or didn't). Read-only."
---

# Match Routes to Filters

## When to Use

Run this skill from `/auth-audit` or as part of `/security-audit`. It is the structural backbone of the auth audit — it produces the data; the calling agent classifies severity per `rules/security-audit.md`.

Read-only. Never invokes other agents. Output is a structured JSON matrix.

## Do NOT

- Compile or run code. The matrix is built from static parsing of source.
- Assume routes documented in OpenAPI but not actually present in the controller. Source is the source of truth.
- Treat absence of a `SecurityWebFilterChain` config as "no security needed." If no filter chain exists at all, every handler is **unmatched** and the BLOCKER count equals the handler count.

## Steps

- [ ] **Step 1: Locate the inbound module + filter-chain config**

```bash
# Inbound HTTP usually lives under adapters/inbound/. Be flexible — some projects put it elsewhere.
inbound_dirs=$(grep -rl '@RestController' --include='*.kt' --exclude-dir=build --exclude-dir=test . 2>/dev/null \
  | xargs -I{} dirname {} 2>/dev/null | sort -u || true)

# Filter-chain config is wherever a @Bean SecurityWebFilterChain (or @EnableWebFluxSecurity) is declared.
filter_config=$(grep -rlnE 'SecurityWebFilterChain\b|@EnableWebFluxSecurity' --include='*.kt' \
  --exclude-dir=build --exclude-dir=test . 2>/dev/null | head -3 || true)
```

If `filter_config` is empty: emit the "no filter chain" warning early. The matrix is still produced — every handler will report **unmatched**.

- [ ] **Step 2: Enumerate handlers**

For each `*.kt` under the inbound dirs, find every `@<HTTP-Method>Mapping` annotation and capture:

- HTTP method (`GET` / `POST` / `PUT` / `DELETE` / `PATCH`)
- Path pattern (the annotation's `value` or `path` attribute, joined with the class-level `@RequestMapping` if present)
- Function name + file:line
- Method-level security annotations (`@PreAuthorize`, `@Secured`, `@RolesAllowed`) — these are an alternative to filter-chain rules and count as authenticated

```bash
# Sketch — the agent fills in the parsing details. Look for:
#   class-level: @RequestMapping("/api/v1/orders")
#   method-level: @PostMapping("/{id}/cancel"), @GetMapping, @DeleteMapping("/all"), etc.
grep -nE '@(Get|Post|Put|Delete|Patch|Request)Mapping' \
  --include='*.kt' --exclude-dir=build --exclude-dir=test \
  -r adapters/inbound 2>/dev/null
```

- [ ] **Step 3: Parse the filter-chain rules**

Read each file in `filter_config`. Extract the route-pattern → authorization-rule mapping. The common shapes:

```kotlin
http
    .authorizeExchange { spec ->
        spec
            .pathMatchers("/actuator/**").permitAll()
            .pathMatchers(HttpMethod.POST, "/api/v1/auth/**").permitAll()
            .pathMatchers("/api/v1/admin/**").hasRole("ADMIN")
            .anyExchange().authenticated()
    }
```

Capture, in source order:
- HTTP method (or `ANY`)
- Path pattern (Ant-style; `/api/v1/orders/**` matches `/api/v1/orders` and any sub-path)
- Authorization rule (`permitAll`, `denyAll`, `authenticated`, `hasRole(...)`, `hasAuthority(...)`, custom expression)
- The terminal rule: `anyExchange()` or `anyRequest()` — note its authorization.

If no terminal rule exists, the chain may default to `denyAll` (Spring Security 6+). Surface this in the output.

- [ ] **Step 4: Match each handler to a rule**

For each handler `(method, path)`:

1. Walk the rule list **in source order** (Spring Security evaluates first-match-wins).
2. The first rule whose method matches (or is `ANY`) AND whose path pattern matches the handler's path → that's the handler's authorization rule.
3. If no rule matches → handler is **unmatched** (the terminal rule applies).

Detect **shadowing**: if a `permitAll()` rule matches AND a later rule (in source order) would also match the same handler, surface this as a separate "shadowed" record. The shadowed record cites both file:lines.

If a handler has a method-level `@PreAuthorize`, classify it as **authenticated-by-method** even if the filter chain says `permitAll` — the method-level rule takes precedence at runtime.

- [ ] **Step 5: Emit the matrix**

```json
{
  "service":          "<service-name>",
  "handlers_total":   47,
  "filter_config":    "boot/SecurityConfig.kt:24",
  "terminal_rule":    "authenticated",
  "matrix": [
    {
      "method":           "POST",
      "path":             "/api/v1/admin/users/{id}/promote",
      "handler_file":     "adapters/inbound/admin/UserAdminController.kt:34",
      "matched_rule":     null,
      "matched_rule_file": null,
      "class":            "unmatched",
      "method_level_security": null
    },
    {
      "method":           "POST",
      "path":             "/api/v1/orders",
      "handler_file":     "adapters/inbound/orders/OrderController.kt:28",
      "matched_rule":     "authenticated",
      "matched_rule_file": "boot/SecurityConfig.kt:31",
      "class":            "authenticated",
      "method_level_security": null
    },
    {
      "method":           "GET",
      "path":             "/actuator/info",
      "handler_file":     null,
      "matched_rule":     "permitAll",
      "matched_rule_file": "boot/SecurityConfig.kt:27",
      "class":            "permit-all-by-rule",
      "rationale_annotation": "// PUBLIC: actuator info is read-only and used by health probes"
    },
    {
      "method":           "POST",
      "path":             "/api/v1/legacy/import",
      "handler_file":     "adapters/inbound/legacy/LegacyImportController.kt:18",
      "matched_rule":     "permitAll",
      "matched_rule_file": "boot/SecurityConfig.kt:25",
      "class":            "shadowed",
      "shadowing_rule":   "hasRole('ADMIN')",
      "shadowing_rule_file": "boot/SecurityConfig.kt:33"
    }
  ],
  "summary": {
    "authenticated":         41,
    "permit-all-by-rule":     4,
    "unmatched":              1,
    "shadowed":               1
  }
}
```

Plus a short markdown summary above the JSON for the calling agent. The calling agent (`security-auditor`) classifies severity from the `class` field per the rules.

## Output

JSON matrix + markdown summary. Consumed by `security-auditor` to produce the final audit report.

## Notes

- For Kotlin DSL filter configs (`http { authorizeExchange { ... } }`), parsing requires recognising the DSL form. If the project uses `@Configuration` Java-style, the parser handles both.
- Path patterns are Ant-style. The matcher must handle `?` (one char), `*` (path segment), `**` (any depth). The Spring Boot canonical implementation is `AntPathMatcher` — the skill mirrors its behaviour.
- For projects using `spring-cloud-gateway` route filters as the auth boundary, this skill returns "auth boundary is upstream" and skips the matrix — gateway audits are out of scope.
- Method-level security (`@PreAuthorize`, `@Secured`) only applies if `@EnableReactiveMethodSecurity` is present. The skill checks for that annotation and adjusts classification accordingly.
