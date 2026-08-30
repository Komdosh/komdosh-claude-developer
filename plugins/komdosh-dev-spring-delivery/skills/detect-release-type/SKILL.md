---
name: detect-release-type
user-invocable: false
description: "Read git log <last-tag>..HEAD, classify each commit via Conventional Commits, and recommend a major/minor/patch bump. Returns structured JSON + a one-line rationale. Read-only. Used by /version-bump and the release-coordinator."
---

# Detect Release Type

Decides the next bump from commit history. Both tracks call it; the **library track wraps it with `produce-abi-report` and overrides the result** when the ABI shows a break.

Read-only. Refuse with a clear message outside a git work tree.

## 1. Window

Base is the newest release tag (`v[0-9]*`, **excluding pre-release suffixes** — an `-rc` never advances the base). Never tagged → the root commit, and **cap the proposal at `minor`**: auto-proposing `1.0.0` for a multi-year unreleased project is almost never right. Flag and ask instead.

`git log "$base..HEAD" --no-merges` — merge commits are skipped even when a `--no-ff` merge carries a real-looking subject.

## 2. Classify

Parse `^(feat|fix|perf|refactor|docs|test|chore|ci|build|style|revert)(\(scope\))?(!)?: `, plus a `BREAKING CHANGE:` / `BREAKING-CHANGE:` footer in the body.

| Signal | Bump |
|---|---|
| `!` before the colon, or a breaking footer | **major** |
| `feat` | minor |
| `fix`, `perf` | patch |
| `refactor`, `revert` | patch — a refactor users can see should have been marked `!` |
| `docs`, `test`, `chore`, `ci`, `build`, `style` | none — skipped from the computation entirely |

**Only `!` or the literal footer signal a break.** A body that merely mentions "break" does not.

## 3. Aggregate and report

Highest signal wins; all-skipped means `none` — no release needed.

JSON: `base`, `head`, `commits`, `skipped`, `by_prefix`, `breaking`, `proposed_bump`, `rationale`. The rationale is one sentence naming the strongest signal and its commit — "major because a1b2c3d (`feat!: rename …`) marks a breaking change".

## Pre-1.0

While the project is on `0.x.y`, semver §4 applies: a major signal becomes minor, a minor signal becomes patch. Normal rules resume at `1.0.0`.
