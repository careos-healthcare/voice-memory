#!/usr/bin/env bash
# Move uncommitted ambient, watch, and cleanup work off the PR branch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SOURCE_BRANCH="cursor/time-of-day-rich-imports"
TARGET_BRANCH="feature/ambient-watch-cleanup"
STASH_MESSAGE="WIP: ambient context, watch work, and feature cleanup"

current="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current" != "$SOURCE_BRANCH" ]]; then
  echo "error: switch to $SOURCE_BRANCH before running (currently $current)" >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  echo "error: $TARGET_BRANCH already exists" >&2
  exit 1
fi

# `git stash save` without --include-untracked leaves new files in the
# worktree, and those files follow every later checkout.
git stash save --include-untracked "$STASH_MESSAGE"

git push origin "$SOURCE_BRANCH"

# The saved work was edited on top of SOURCE_BRANCH. Replaying it onto
# main conflicts where both sides changed the same file, so the new branch
# starts at the PR tip. That ref itself is left unchanged.
git checkout -b "$TARGET_BRANCH" "$SOURCE_BRANCH"

if ! git stash pop; then
  echo "error: the stash did not apply cleanly onto $SOURCE_BRANCH." >&2
  echo "The stash entry is still saved. $SOURCE_BRANCH was left clean." >&2
  exit 1
fi

# Stash pop stages tracked edits. Return them to the unstaged worktree.
git reset

echo "ok: $SOURCE_BRANCH is published and the saved work is on $TARGET_BRANCH"
