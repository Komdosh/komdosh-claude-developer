#!/usr/bin/env bash
# Fires after Edit/Write/MultiEdit on a *Controller.kt file.
# If docs/qa/manual-validation-plan.md exists and is older than the controller
# that was just edited, prints a hint to re-run /qa-plan. Otherwise no-ops.
#
# Reads tool input as JSON from stdin (Claude Code hook contract).
# Prints to stderr — Claude Code surfaces stderr to the model as a hook notice.

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || echo "")

# only fire on *Controller.kt edits
case "$file_path" in
  *Controller.kt) ;;
  *) exit 0 ;;
esac

# resolve project root from the env var Claude Code provides
project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
plan="$project_root/docs/qa/manual-validation-plan.md"

# nothing to warn about if the plan doesn't exist yet
[ -f "$plan" ] || exit 0

# nothing to warn about if the file path doesn't actually exist on disk
[ -e "$file_path" ] || exit 0

# stale if the controller is newer than the plan
if [ "$file_path" -nt "$plan" ]; then
  cat >&2 <<EOF
QA hint: $file_path was just edited but $plan was last refreshed earlier.
Run /qa-plan to regenerate the manual validation plan (checked boxes will be preserved by step id).
EOF
fi

exit 0
