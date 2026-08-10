---
name: detect-release-type
user-invocable: false
description: "Read git log <last-tag>..HEAD, classify each commit via Conventional Commits, and recommend a major/minor/patch bump. Returns structured JSON + a one-line rationale. Read-only. Used by /version-bump and the release-coordinator."
---

# Detect Release Type

## When to Use

Use this skill any time the next version number must be decided from commit history. Both tracks call it; the **library track** wraps it with `produce-abi-report` and overrides the result if breaking ABI deltas are present.

Read-only. Never modifies files.

## Do NOT

- Skip merge commits incorrectly. The skill DOES skip them — but a `--no-ff` merge commit with a real subject (`Merge branch 'feat/...'`) is still a merge and is skipped.
- Treat `chore`, `ci`, `test`, `build`, `style`, `docs` commits as bump signals. They are skipped from bump computation.
- Force a major bump just because a commit body mentions "break". The signal is `feat!`, `fix!`, `refactor!`, OR a literal `BREAKING CHANGE:` footer in the body.

## Steps

- [ ] **Step 1: Locate the last release tag**

```bash
# Guard: refuse on non-git working trees with a clear message.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "not a git repository — detect-release-type cannot run without git history"
  exit 1
}

last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-rc*' --exclude '*-alpha*' --exclude '*-beta*' 2>/dev/null || echo "")

if [ -z "$last_tag" ]; then
  # never released; treat the root commit as the base
  base=$(git rev-list --max-parents=0 HEAD | head -1)
else
  base="$last_tag"
fi

echo "base=$base"
```

- [ ] **Step 2: List commits in the window**

```bash
git log "$base..HEAD" --no-merges --pretty=format:'%H%x09%s%x09%b%x1e'
```

Each record: `<sha>\t<subject>\t<body>` separated by `\x1e`.

Records with empty subject are dropped.

- [ ] **Step 3: Parse each commit**

Extract:

- **prefix**: regex `^(feat|fix|perf|refactor|docs|test|chore|ci|build|style|revert)(\([^)]+\))?(!)?: `
- **scope**: from the parens after the prefix.
- **bang**: presence of `!` before the colon.
- **breaking-footer**: presence of `^BREAKING CHANGE:` (or `^BREAKING-CHANGE:`) in the body.
- **subject**: everything after the prefix.

Skip the commit if no recognised prefix is found AND no breaking footer is present.

- [ ] **Step 4: Compute the bump signal per commit**

| Signal | Bump |
|---|---|
| `bang == true` OR `breaking-footer == true` | major |
| `prefix == feat` | minor |
| `prefix in (fix, perf)` | patch |
| `prefix in (refactor, revert)` | patch (refactors should be invisible to users; if they're not, the author should mark `!`) |
| `prefix in (docs, test, chore, ci, build, style)` | none (skipped from bump) |

- [ ] **Step 5: Aggregate**

Pick the highest bump across all commits:

```
if any commit signals major  → major
elif any commit signals minor → minor
elif any commit signals patch → patch
else                         → none  (informational; no release needed)
```

- [ ] **Step 6: Compose the rationale**

One sentence referencing the strongest signal. Examples:

- `major because commit a1b2c3d (feat!: rename CreateOrderRequest.customerEmail to email) marks a breaking change`
- `minor because 3 feat: commits and 2 fix: commits`
- `patch because only fix: and perf: commits`
- `none because all commits are chore/ci/docs — no release needed`

- [ ] **Step 7: Output JSON**

```json
{
  "base":           "<short-sha-or-tag>",
  "head":           "<short-sha>",
  "commits":        N,
  "skipped":        K,
  "by_prefix":      { "feat": 3, "fix": 2, "chore": 5, "ci": 1 },
  "breaking":       1,
  "proposed_bump":  "patch | minor | major | none",
  "rationale":      "<one sentence>"
}
```

Plus a human-readable summary above the JSON for the agent that called the skill.

## Output

Markdown summary + JSON block. Both consumed downstream:

- The `release-coordinator` agent reads the JSON to drive `/version-bump`.
- A user invoking `/version-bump --dry-run` sees the markdown summary first.

## Notes

- For projects that use `0.0.x` in early development (no major bump yet): the skill treats `0.x.y` as informal — major signals from commits become minor in semver, minor signals become patch. This matches semver §4. Once the project hits `1.0.0`, normal rules resume.
- For pre-release tags (`v1.4.0-rc.1`): the base for the window is the most recent NON-pre-release tag. The pre-release suffix never advances the base.
- For projects that never had a tag: the entire history is the window, but the proposed bump is capped at `minor` (you almost certainly don't want to ship `1.0.0` from a multi-year unreleased project on autopilot — flag and ask).
