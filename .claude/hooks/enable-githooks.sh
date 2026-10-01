#!/usr/bin/env bash
# enable-githooks.sh — Claude Code SessionStart hook.
# core.hooksPath is per clone and cannot be committed, so a fresh clone runs no commit gate and
# harness-lint fails with [gate.hookspath]. This turns the gate on for the clone a session opens
# in, the same rule the hub's platform/sync applies to the clones it makes: set it only when it is
# unset, never override a value the clone chose, and say so when it changes anything.
# A human who never opens a session still runs `git config core.hooksPath .githooks` once
# (CONTRIBUTING.md). Always exits 0: a SessionStart hook must never block a session.
dir=${CLAUDE_PROJECT_DIR:-$(pwd)}
[ -d "$dir/.githooks" ] || exit 0
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0
cur=$(git -C "$dir" config core.hooksPath 2>/dev/null || true)
if [ -z "$cur" ]; then
  if git -C "$dir" config core.hooksPath .githooks 2>/dev/null; then
    echo '{"systemMessage": "Commit gate enabled on this clone: set git config core.hooksPath .githooks (it was unset)."}'
  fi
elif [ "$cur" != ".githooks" ]; then
  echo "{\"systemMessage\": \"core.hooksPath is '$cur', not .githooks, so this repository's commit gate does not run here. Left as the clone set it.\"}"
fi
exit 0
