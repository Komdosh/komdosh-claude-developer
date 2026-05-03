# /pr-summary

Produce a PR/MR description from the current git state. Platform-agnostic: detects GitHub, GitLab, Bitbucket, or other from the remote URL and suggests the matching CLI command or provides the body for manual paste.

## Steps

- [ ] **Step 1: Gather git state**

```bash
git status
git log main..HEAD --oneline
git diff main..HEAD --stat
```

If `git log main..HEAD` is empty, check the current branch vs its tracking branch:
```bash
git log @{upstream}..HEAD --oneline 2>/dev/null || git log HEAD~5..HEAD --oneline
```

- [ ] **Step 2: Read the diff for context**

```bash
git diff main..HEAD -- '*.kt' '*.yaml' '*.toml' '*.json' '*.sql' 2>/dev/null | head -400
```

- [ ] **Step 3: Detect remote platform**

```bash
git remote get-url origin 2>/dev/null || echo "NO REMOTE"
```

- Contains `github.com` → **GitHub**: suggest `gh pr create`
- Contains `gitlab` → **GitLab**: suggest `glab mr create`
- Contains `bitbucket.org` → **Bitbucket**: provide body for manual paste in the Bitbucket UI
- No remote or other → provide body for manual paste

- [ ] **Step 4: Produce the PR/MR body**

```markdown
## What
- <bullet: what changed — be specific, not "updated code">
- <bullet: second change if distinct>
- <bullet: third change if distinct>

## Why
<1-2 sentences: the business or technical motivation for these changes>

## How
<Key implementation decisions a reviewer needs to understand. E.g., "Uses TransactionalOperator instead of @Transactional because the service method is suspend fun." Omit if changes are straightforward.>

## Test Plan
- [ ] Unit tests: <what was covered, e.g., "OrderService.create — success and validation cases">
- [ ] Integration tests: <what was covered, or "N/A">
- [ ] Manual verification: <what to check in the running service, or "N/A">
```

- [ ] **Step 5: Output the CLI command or paste instructions**

**If GitHub:**
```bash
gh pr create \
  --title "<concise title under 70 chars>" \
  --body "$(cat <<'EOF'
<body from Step 4>
EOF
)"
```

**If GitLab:**
```bash
glab mr create \
  --title "<concise title under 70 chars>" \
  --description "$(cat <<'EOF'
<body from Step 4>
EOF
)"
```

**If Bitbucket or other:**
"No CLI detected. Copy this body into the PR/MR description field in the web UI:"
[paste body]
