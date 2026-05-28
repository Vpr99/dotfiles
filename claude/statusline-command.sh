#!/bin/bash

# Read JSON input
input=$(cat)

# Extract values from JSON (without jq)
cwd=$(echo "$input" | sed -n 's/.*"current_dir":"\([^"]*\)".*/\1/p')

# Git information (skip optional locks for performance)
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  # Show the repo's top-level dir name
  repo_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  repo_name=$(basename "${repo_root:-$cwd}")

  # Get branch
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

  # Count staged files
  staged=$(git -C "$cwd" --no-optional-locks diff --cached --name-only 2>/dev/null | wc -l)

  # Count unstaged files (modified + deleted, not untracked)
  unstaged=$(git -C "$cwd" --no-optional-locks diff --name-only 2>/dev/null | wc -l)

  # Count untracked files
  untracked=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l)

  printf '\033[01;36m%s\033[00m | \033[01;32m%s\033[00m | S: \033[01;33m%s\033[00m | U: \033[01;33m%s\033[00m | A: \033[01;33m%s\033[00m' \
    "$repo_name" "$branch" "$staged" "$unstaged" "$untracked"
else
  # Not a git repo
  printf '\033[01;36m%s\033[00m' "$cwd"
fi