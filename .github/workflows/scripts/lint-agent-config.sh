#!/usr/bin/env bash
# lint-agent-config.sh — integrity check for a SPOKE repo's agent config.
# Run from the spoke repo root (gated by .github/workflows/agent-config-lint.yml). CLAUDE.md is the
# primary file in a WebPros spoke and AGENTS.md is a symlink to it, so the five sections and the
# mirrored boundary set live in CLAUDE.md. A spoke using the other convention (ADR-016: canonical
# AGENTS.md, loaded by a thin root CLAUDE.md through `@AGENTS.md`) passes too. bash 3.2-safe.
set -euo pipefail

fail=0
err()  { echo "FAIL: $*" >&2; fail=1; }
warn() { echo "warn: $*" >&2; }
ok()   { echo "ok:   $*"; }

# 1) The agent config carries the five sections, and Constraints mirrors BOUND-* (not dropped).
#    Primary: CLAUDE.md, with AGENTS.md a symlink to it (no import — it would import itself).
#    Also accepted: a canonical AGENTS.md that a thin CLAUDE.md imports with `@AGENTS.md`.
primary=""
if [ ! -f CLAUDE.md ]; then
  err "CLAUDE.md is missing (it is the primary agent config; AGENTS.md links to it)"
elif [ ! -e AGENTS.md ]; then
  err "AGENTS.md is missing — link it to the primary file: ln -s CLAUDE.md AGENTS.md"
elif [ AGENTS.md -ef CLAUDE.md ]; then
  primary=CLAUDE.md
  ok "AGENTS.md links to CLAUDE.md (CLAUDE.md is primary; no import needed)"
elif grep -qF "@AGENTS.md" CLAUDE.md; then
  primary=AGENTS.md
  ok "CLAUDE.md imports @AGENTS.md"
else
  err "AGENTS.md is a separate file that CLAUDE.md never loads — replace it with a link (ln -sf CLAUDE.md AGENTS.md), or import it from CLAUDE.md with '@AGENTS.md'"
fi
if [ -n "$primary" ]; then
  miss=""
  for section in "## Conventions" "## Constraints" "## Domain context" "## Tools" "## Reading list"; do
    grep -qiF "$section" "$primary" || miss="$miss $section"
  done
  if [ -n "$miss" ]; then err "$primary missing section(s):$miss"; else ok "$primary sections present"; fi
  awk '/^## Constraints/{f=1;next} /^## /{f=0} f&&/BOUND-/{n++} END{exit !(n>0)}' "$primary" \
    || err "$primary: Constraints section mirrors no BOUND-* rules"
fi

# 2) Conventional Commits gate wired.
if git rev-parse --git-dir >/dev/null 2>&1; then
  hookpath=$(git config core.hooksPath 2>/dev/null || true)
  if { [ -x .githooks/commit-msg ] && [ "$hookpath" = ".githooks" ]; } || [ -x .husky/commit-msg ]; then
    ok "commit-msg hook wired"
  else
    err "commit gate not active — need .githooks/commit-msg + 'git config core.hooksPath .githooks' (or husky)"
  fi
  # The rule set lives in .github/ (the workflow names it: configFile: .github/commitlint.config.cjs);
  # a root copy is one the workflow never reads.
  if [ -f .github/commitlint.config.cjs ]; then
    ok "commitlint config present: .github/commitlint.config.cjs"
  elif [ -f commitlint.config.cjs ] || [ -f commitlint.config.js ]; then
    err "commitlint config is at the root — move it to .github/commitlint.config.cjs (git mv) and point commitlint.yml's configFile there"
  else
    err "commitlint config missing (.github/commitlint.config.cjs)"
  fi
else
  warn "not a git repo — skipping commit-hook wiring check"
fi

# 3) The agent guards come from the engineering-harness plugin, not from a copied hook. The plugin
#    ships block-commit-bypass and block-unapproved-merge as PreToolUse hooks; a bash copy beside it
#    runs the same check twice and drifts.
if [ ! -f .claude/settings.json ]; then
  err ".claude/settings.json missing (restore it from the spoke scaffold variant: platform/spoke-template/<python|typescript>/.claude/settings.json)"
elif ! grep -qE '"engineering-harness@webpros"[[:space:]]*:[[:space:]]*true' .claude/settings.json; then
  err ".claude/settings.json does not enable engineering-harness@webpros, which ships the agent guards"
elif grep -qF "block-commit-bypass.sh" .claude/settings.json || [ -e .claude/hooks/block-commit-bypass.sh ]; then
  err "the bash block-commit-bypass.sh is still here — the plugin ships the guard; delete the file and its wiring"
else
  ok "agent guards: engineering-harness plugin enabled"
fi

# 4) Contract artifact pinned, not forked.
[ -e contracts/system/architecture/contract.yaml ] || warn "contracts/system/architecture/contract.yaml not found — pin the hub-published contracts/ ref"

if [ "$fail" -eq 0 ]; then echo "agent-config lint: PASS"; else echo "agent-config lint: FAIL"; exit 1; fi
