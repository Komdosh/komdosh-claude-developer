#!/usr/bin/env bash
# Fires after Write/Edit/MultiEdit on a Liquibase changeset under db/changelog/.
# If the new V<N>__<slug>.sql is not yet referenced in db.changelog-master.yaml,
# emits the reminder as PostToolUse JSON additionalContext on stdout — the only
# channel the model sees on exit 0 (stderr on exit 0 lands in the transcript, not Claude).

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || echo "")

# only fire on Liquibase changeset writes under db/changelog/
case "$file_path" in
  */db/changelog/V*__*.sql) ;;
  *) exit 0 ;;
esac

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"

# locate the master changelog (first match). `|| true` defends against pipefail aborts
# in case `find` is ever swapped for a stricter helper that exits non-zero on no-match.
master=$(find "$project_root" -name 'db.changelog-master.yaml' -not -path '*/build/*' -not -path '*/.gradle/*' 2>/dev/null | head -1 || true)
[ -n "$master" ] || exit 0

basename=$(basename "$file_path")

# already registered? grep for the basename in the master changelog
if grep -qF "$basename" "$master"; then
  exit 0
fi

hint="Migration hint: $basename was written but is not yet referenced in $master.
Add an entry like:
  - include:
      file: db/changelog/$basename
      relativeToChangelogFile: true
Liquibase will not apply unregistered changesets."

jq -n --arg ctx "$hint" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}, suppressOutput: true}'

exit 0
