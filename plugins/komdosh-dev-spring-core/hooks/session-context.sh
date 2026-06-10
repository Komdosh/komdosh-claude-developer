#!/usr/bin/env bash
# SessionStart hook: if the project has a service.yaml (the marker file the core
# plugin's read-service-context skill looks for), inject its head plus the mandatory
# preflight-skill map as additionalContext — so every session starts oriented without
# spending a Skill invocation on read-service-context.
#
# Silent no-op when the project has no service.yaml/service.yml (the plugin may be
# installed user-scope and the current repo isn't a Kotlin/Spring service).
# Emits SessionStart JSON additionalContext on stdout; never blocks session start.

set -euo pipefail

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"

svc=""
for candidate in service.yaml service.yml; do
  if [ -f "$project_root/$candidate" ]; then
    svc="$project_root/$candidate"
    break
  fi
done
[ -n "$svc" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

# Head only — service.yaml is small by convention, but never flood the context.
summary=$(head -40 "$svc" || true)

ctx="Service context (auto-injected from ${svc#"$project_root"/} by komdosh-dev-spring-core SessionStart hook — read-service-context already satisfied for this session):

$summary

Mandatory preflight skills for this repo:
- coroutine-safety-scan + module-boundary-check after editing Kotlin under domain/, application/, or adapters/
- liquibase-changeset-immutability before committing changes that touch V*.sql
- jooq-generation-freshness after editing any V*.sql
- run-verification (narrowest-first Gradle) before reporting any code change done"

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}, suppressOutput: true}'

exit 0
