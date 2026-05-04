#!/usr/bin/env bash
# Fires before Bash invocations. If the command starts with `git tag` (and isn't a `-d` delete or a `-l` list),
# looks up the project's track via service.yaml, runs the matching readiness skill, and prints failing gates
# with remediation hints. Advisory only — exits 0 regardless of readiness state. Never blocks the tag.
#
# Reads tool input as JSON from stdin (Claude Code hook contract). Prints to stderr — Claude Code
# surfaces stderr to the model.

set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# only fire on `git tag` invocations that create or sign a tag
case "$command" in
  *"git tag -d "*)         exit 0 ;;  # tag delete — never validate
  *"git tag -l"*)          exit 0 ;;  # tag list — read-only
  *"git tag --list"*)      exit 0 ;;
  "git tag")               exit 0 ;;  # bare `git tag` is also list
  *"git tag "*)            ;;          # creating a tag — proceed
  *)                       exit 0 ;;
esac

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"

# detect track
kind=""
if [ -f "$project_root/service.yaml" ]; then
  kind=$( (grep -E '^kind:\s*' "$project_root/service.yaml" 2>/dev/null || true) | awk '{print $2}' | tr -d '"' | head -1)
elif [ -f "$project_root/service.yml" ]; then
  kind=$( (grep -E '^kind:\s*' "$project_root/service.yml" 2>/dev/null || true) | awk '{print $2}' | tr -d '"' | head -1)
fi

if [ -z "$kind" ]; then
  # heuristic fallback. Match runApplication<...>(...) directly — *Application.kt naming is convention, not load-bearing.
  # In multi-module Gradle projects, the spring-boot and maven-publish plugins are applied per-module — recursive grep.
  # `|| true` after each pipeline because under `set -e -o pipefail` a grep with no matches (exit 1) would abort.
  has_app=$(grep -rl 'runApplication<' --include='*.kt' \
              --exclude-dir=build --exclude-dir=test --exclude-dir='.gradle' \
              "$project_root" 2>/dev/null | head -1 || true)
  has_publish=$(grep -rlE 'maven-publish' --include='build.gradle.kts' \
                  --exclude-dir=build --exclude-dir='.gradle' \
                  "$project_root" 2>/dev/null | head -1 || true)
  has_boot=$(grep -rlE 'org\.springframework\.boot' --include='build.gradle.kts' \
               --exclude-dir=build --exclude-dir='.gradle' \
               "$project_root" 2>/dev/null | head -1 || true)
  # `runApplication<>` only appears in Spring Boot apps — it's the strongest signal of a service.
  # `has_boot` is informational; many repos apply the Spring Boot plugin via buildSrc convention plugins (id("project.boot-conventions")) so it won't appear in service build.gradle.kts files.
  if   [ -n "$has_app" ];                                                then kind="service"
  elif [ -n "$has_publish" ] && [ -z "$has_app" ];                       then kind="library"
  fi
fi

if [ -z "$kind" ]; then
  cat >&2 <<EOF
Release hint: about to create a git tag, but track (service vs library) could not be determined.
Add 'kind: service' or 'kind: library' to service.yaml to enable readiness validation on tag creation.
EOF
  exit 0
fi

cat >&2 <<EOF
Release hint: about to create a git tag (track: $kind).
Recommend running /release-prep before tagging to confirm readiness gates are GREEN.

  /release-prep --track=$kind

If /release-prep was already run cleanly within the last 10 minutes, this hint can be ignored.
EOF

exit 0
