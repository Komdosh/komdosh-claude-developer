---
name: match-routes-to-filters
user-invocable: false
description: "Builds a coverage matrix of every @RestController handler vs the project's SecurityWebFilterChain rules. Classifies each handler as authenticated / permit-all-by-rule / unmatched / shadowed. Surfaces the file:line for both the handler and the filter rule that matched (or didn't). Read-only."
---

# Match Routes to Filters

The structural backbone of the auth audit: this produces the matrix, `security-auditor` assigns severity per `rules/security-audit.md`.

Read-only and static. **Never compile or run anything, and never trust OpenAPI over source** — a documented route that isn't in a controller does not exist, and a controller route missing from the docs still serves traffic.

**No filter chain at all is not "no security needed."** Every handler is then unmatched, and the finding count equals the handler count. Say that plainly.

## 1. Enumerate handlers

Every `@(Get|Post|Put|Delete|Patch|Request)Mapping` under wherever `@RestController` actually lives — usually `adapters/inbound/`, but don't assume. Capture the HTTP method, the path (class-level `@RequestMapping` joined with the method-level one), the function's `file:line`, and any method-level `@PreAuthorize`/`@Secured`/`@RolesAllowed`.

## 2. Parse the chain

From wherever `SecurityWebFilterChain` or `@EnableWebFluxSecurity` is declared, capture **in source order**: the HTTP method (or ANY), the Ant path pattern, and the authorization rule. Handle both the Kotlin DSL and Java-style config.

Note the terminal `anyExchange()` rule explicitly. **If there is no terminal rule, say so** — Spring Security 6+ may default to `denyAll`, and the difference decides whether every unmatched route is open or closed.

## 3. Match — first rule wins

Walk the rules in source order; the first whose method and Ant pattern match owns the handler. Pattern semantics mirror `AntPathMatcher`: `?` one character, `*` one segment, `**` any depth.

- **No rule matches** → `unmatched`, and the terminal rule decides its real posture.
- **A `permitAll()` matches first while a later rule would also match** → `shadowed`, citing **both** `file:line`s. The later rule never fires, so this is a rule the author believes is in effect and is not.
- **A method-level `@PreAuthorize`** → `authenticated-by-method`, which takes precedence over a `permitAll` in the chain — but **only when `@EnableReactiveMethodSecurity` is present**. Check for it; without it those annotations are inert and the handler is as open as the chain says.

## 4. Emit

JSON with `handlers_total`, the filter-config location, the terminal rule, a `matrix` row per handler (`method`, `path`, `handler_file`, `matched_rule`, `matched_rule_file`, `class`, plus `shadowing_rule*` or `method_level_security` where they apply, and any `// PUBLIC:` rationale found), and a `summary` count per class. A short markdown summary goes above it.

Where the auth boundary is an upstream gateway rather than the service, return "auth boundary is upstream" and skip the matrix — gateway audits are out of scope.
