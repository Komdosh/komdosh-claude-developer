#!/usr/bin/env bash
# Marketplace-wide static lint — runs every check that the smoke tests
# (and the bugs they surfaced) taught us to look for. Catches regressions
# before they reach the first user. Run from the repo root.
#
# Exit code: 0 if all checks pass; 1 if any check fails. Errors print to
# stderr; per-check section headers print to stdout.
#
# What it checks:
#   1. JSON validity for every plugin.json + every hooks.json + marketplace.json.
#   2. plugin.json `name` matches its directory.
#   3. Every plugin in marketplace.json points at an existing directory.
#   4. Frontmatter on every agent/command/skill: has name + description; agents have model.
#   5. Markdown links inside CLAUDE.md resolve to actual files.
#   6. No double-dash directory names under skills/ (e.g. `verify-something--service`).
#   7. Hook .sh files: bash syntax OK, executable bit set.
#   8. set -euo pipefail + grep|head pipelines without `|| true` (the bug class).
#   9. No remaining cross-references to renamed plugins.

set -uo pipefail

# colors only when stdout is a TTY
if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'; else GREEN=''; RED=''; YELLOW=''; NC=''; fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

failures=0
warnings=0
checks=0

pass()    { checks=$((checks+1)); printf '  %b%s%b  %s\n' "$GREEN" "PASS" "$NC" "$1"; }
fail()    { checks=$((checks+1)); failures=$((failures+1)); printf '  %b%s%b  %s\n' "$RED" "FAIL" "$NC" "$1" >&2; }
warn()    { checks=$((checks+1)); warnings=$((warnings+1)); printf '  %b%s%b  %s\n' "$YELLOW" "WARN" "$NC" "$1"; }
section() { printf '\n%b%s%b\n' "${YELLOW}" "== $1 ==" "$NC"; }

# ---------------------------------------------------------------------
section "1. JSON validity"
for f in .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json plugins/*/hooks/hooks.json; do
  [ -f "$f" ] || continue
  if jq -e . "$f" >/dev/null 2>&1; then
    pass "$f"
  else
    fail "$f — invalid JSON"
  fi
done

# ---------------------------------------------------------------------
section "2. plugin.json name matches directory"
for f in plugins/*/.claude-plugin/plugin.json; do
  dir=$(basename "$(dirname "$(dirname "$f")")")
  name=$(jq -r '.name // ""' "$f" 2>/dev/null)
  if [ "$name" = "$dir" ]; then
    pass "$dir"
  else
    fail "$dir — plugin.json declares name=$name"
  fi
done

# ---------------------------------------------------------------------
section "3. marketplace.json plugins all exist"
while read -r entry; do
  name=$(printf '%s' "$entry" | jq -r .name)
  source=$(printf '%s' "$entry" | jq -r .source)
  if [ -d "$source" ]; then
    pass "$name → $source"
  else
    fail "$name → $source (directory missing)"
  fi
done < <(jq -c '.plugins[]' .claude-plugin/marketplace.json 2>/dev/null)

# ---------------------------------------------------------------------
section "4. Frontmatter on agents / commands / skills"
for f in plugins/*/agents/*.md plugins/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
  has_name=$(echo "$fm" | grep -cE '^name:\s+' || true)
  has_desc=$(echo "$fm" | grep -cE '^description:\s+' || true)
  case "$f" in
    *agents*) has_model=$(echo "$fm" | grep -cE '^model:\s+' || true)
              if [ "$has_name" -eq 1 ] && [ "$has_desc" -eq 1 ] && [ "$has_model" -eq 1 ]; then pass "$f"
              else fail "$f — missing name|description|model in frontmatter"; fi ;;
    *)        if [ "$has_name" -eq 1 ] && [ "$has_desc" -eq 1 ]; then pass "$f"
              else fail "$f — missing name|description in frontmatter"; fi ;;
  esac
done

# ---------------------------------------------------------------------
section "5. Markdown links in CLAUDE.md resolve"
for f in plugins/*/CLAUDE.md; do
  [ -f "$f" ] || continue
  plugin_dir=$(dirname "$f")
  bad=0
  while read -r link; do
    # skip placeholder-shaped links containing < or > (e.g. `docs/plans/<date>-<feature>.md`)
    case "$link" in *'<'*|*'>'*) continue ;; esac
    target="$plugin_dir/$link"
    [ -f "$target" ] || { fail "$f → $link (missing)"; bad=1; }
  done < <(grep -oE '\(([a-z][^)]*\.md|skills/[^)]+/SKILL\.md|rules/[^)]+\.md|agents/[^)]+\.md|commands/[^)]+\.md|hooks/[^)]+\.sh)\)' "$f" | tr -d '()' | sort -u)
  [ "$bad" -eq 0 ] && pass "$f links resolve"
done

# ---------------------------------------------------------------------
section "6. No double-dash skill directories"
bad=$(find plugins -path '*/skills/*--*' -type d 2>/dev/null)
if [ -z "$bad" ]; then
  pass "no -- in skill dir names"
else
  fail "double-dash skill directories: $bad"
fi

# ---------------------------------------------------------------------
section "7. Hook scripts: bash syntax + executable"
for f in plugins/*/hooks/*.sh; do
  [ -f "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then
    if [ -x "$f" ]; then
      pass "$f"
    else
      warn "$f — syntax OK but not executable (chmod +x recommended)"
    fi
  else
    fail "$f — bash syntax error"
  fi
done

# ---------------------------------------------------------------------
section "8. Pipefail bug class — grep | head without || true"
# In hooks that set 'pipefail', any `assignment=$(grep ... | head)` aborts the
# script when grep finds nothing. Surfaced by smoke tests against real Spring
# repos. Detect by finding pipelines under set -*pipefail that lack `|| true`.
for f in plugins/*/hooks/*.sh; do
  [ -f "$f" ] || continue
  if ! grep -qE 'set -[a-z]*o? *pipefail' "$f"; then continue; fi
  # any line that looks like `var=$(... | head ...)` and doesn't contain `|| true`
  bad_lines=$(grep -nE '^\s*[A-Za-z_][A-Za-z0-9_]*=\$\(.*\|\s*head' "$f" | grep -v '|| *true' || true)
  if [ -z "$bad_lines" ]; then
    pass "$f"
  else
    fail "$f — pipeline(s) missing '|| true' under pipefail:"
    printf '%s\n' "$bad_lines" | sed 's/^/        /' >&2
  fi
done

# ---------------------------------------------------------------------
section "9. No leftover spring-* names for plugins now under kotlin-*"
# After the spring→kotlin namespace split, these names should no longer appear.
renamed=(komdosh-dev-spring-extras komdosh-dev-spring-revealer komdosh-dev-spring-doc-revealer)
for old in "${renamed[@]}"; do
  # exclude this lint script itself — it intentionally names the renamed plugins as the check vocabulary.
  hits=$(grep -rl "$old" --include='*.md' --include='*.json' --include='*.sh' . 2>/dev/null \
           | grep -vF 'tools/lint-marketplace.sh' || true)
  if [ -z "$hits" ]; then
    pass "no references to $old"
  else
    fail "references to $old still present in:"
    printf '%s\n' "$hits" | sed 's/^/        /' >&2
  fi
done

# ---------------------------------------------------------------------
printf '\n'
if [ "$failures" -eq 0 ] && [ "$warnings" -eq 0 ]; then
  printf '%bAll %d checks passed.%b\n' "$GREEN" "$checks" "$NC"
  exit 0
elif [ "$failures" -eq 0 ]; then
  printf '%b%d checks passed, %d warning(s).%b\n' "$YELLOW" "$checks" "$warnings" "$NC"
  exit 0
else
  printf '%b%d / %d check(s) failed (%d warning(s)).%b\n' "$RED" "$failures" "$checks" "$warnings" "$NC" >&2
  exit 1
fi
