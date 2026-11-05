#!/usr/bin/env bash
# Usage: run-codex.sh <doc.md> <repo-dir> <out.md> [context-doc.md]
# Runs a read-only Codex simplicity review of <doc.md>, grounded in <repo-dir>.
set -euo pipefail
doc=$1 repo=$2 out=$3 ctx=${4:-}
here=$(cd "$(dirname "$0")" && pwd)
ponytail=$(ls -d ~/.claude/plugins/cache/ponytail/ponytail/*/skills/ponytail 2>/dev/null | sort -V | tail -1)/SKILL.md
{
  cat "$here/reviewer-prompt.md"
  printf '\n# Rubric: Karpathy guidelines\n\n'; cat ~/.agents/skills/karpathy-guidelines/SKILL.md
  printf '\n# Rubric: ponytail\n\n'; cat "$ponytail"
  if [ -n "$ctx" ]; then printf '\n# Context (the approved spec; do not review it, check the plan does not exceed it)\n\n'; cat "$ctx"; fi
  printf '\n# Document under review: %s\n\n' "$(basename "$doc")"; cat "$doc"
} | codex exec -s read-only -C "$repo" --skip-git-repo-check --ephemeral \
      -c model_reasoning_effort=high -o "$out" - >/dev/null 2>"$out.log"
