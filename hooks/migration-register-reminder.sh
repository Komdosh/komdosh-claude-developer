#!/usr/bin/env bash
# Fires after Write/Edit/MultiEdit on a Liquibase changeset under db/changelog/.
# If the new V<N>__<slug>.sql is not yet referenced in db.changelog-master.yaml,
# prints a reminder. Otherwise no-ops.

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || echo "")

# only fire on Liquibase changeset writes under db/changelog/
case "$file_path" in
  */db/changelog/V*__*.sql) ;;
  *) exit 0 ;;
esac

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"

# locate the master changelog (first match)
master=$(find "$project_root" -name 'db.changelog-master.yaml' -not -path '*/build/*' -not -path '*/.gradle/*' 2>/dev/null | head -1)
[ -n "$master" ] || exit 0

basename=$(basename "$file_path")

# already registered? grep for the basename in the master changelog
if grep -qF "$basename" "$master"; then
  exit 0
fi

cat >&2 <<EOF
Migration hint: $basename was written but is not yet referenced in $master.
Add an entry like:
  - include:
      file: db/changelog/$basename
      relativeToChangelogFile: true
Liquibase will not apply unregistered changesets.
EOF

exit 0
