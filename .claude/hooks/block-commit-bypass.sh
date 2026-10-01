#!/usr/bin/env bash
# block-commit-bypass.sh — Claude Code PreToolUse hook (spoke template, copy verbatim).
# Denies `git commit` calls that skip the hooks (--no-verify / -n, or a repointed hooks path), closing the bypass that the
# commit-msg hook can't stop (it can't block a bypass of itself). Heuristic on the command string —
# the spoke's CI (commitlint + the spoke gates) remains the authoritative backstop. Agent-only.
#
# jq parses the hook's JSON stdin. If it's missing we fail OPEN (allow) rather than block every Bash
# call — the matcher is "Bash", so failing closed would brick the agent.
command -v jq >/dev/null 2>&1 || { echo "block-commit-bypass: jq not found; skipping check (CI still gates commits)" >&2; exit 0; }
# jq reads the hook's stdin itself: Claude Code passes it on a socket, and a socket cannot be
# reopened through /dev/stdin (ENXIO), which left cmd empty and the hook allowing everything.
cmd=$(jq -r '.tool_input.command // empty')
# A heredoc body is data, not flags. `-m "$(cat <<'EOF' ... EOF)"` carries whatever the message
# says, and a message is free to contain `grep -rn`, or the literal name of the flag this hook
# blocks. Quote-stripping below cannot see those: heredoc bodies are not quoted spans. So cut the
# command at the heredoc operator, and scan only what precedes it. An invocation that appears only
# after `<<` is quoted text somebody wrote, not a command the shell will run.
#
# Residual gap, deliberate: `cat <<EOF > f; <the invocation> -n` is cut too, so a bypass chained
# after a heredoc is missed. That is the same fail-open posture as the rest of this heuristic, and
# CI re-checks every commit regardless.
scan="${cmd%%<<*}"

# The other way round the gate: repoint the hooks directory, for one commit (`git -c <key>=… commit`)
# or for good (`git config <key> …`, `git config --unset <key>`). Pointing it at .githooks is the
# gate itself and stays allowed, and so does reading the key. Only the text before a segment's
# `commit` / after its `config` is read, so a message that quotes the key is not an invocation.
# Config keys are case-insensitive, so the match is too.
deny_hookspath() {
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
    permissionDecisionReason:"Pointing the hooks path away from .githooks disables the commit gate as completely as --no-verify does — not allowed. If the gate is wrong, change the gate."}}'
  exit 0
}
KEY="core.hooks""path"
lower=$(printf '%s' "$scan" | tr '[:upper:]' '[:lower:]')
while IFS= read -r seg; do
  case "$seg" in
    *git*" commit"*)
      pre="${seg%% commit*}"
      case "$pre" in *"-c"*"$KEY"*)
        val=$(printf '%s' "$pre" | sed -E "s/.*$KEY=?//; s/^[\"']//; s/[\"' ].*//")
        case "$val" in .githooks|./.githooks) ;; *) deny_hookspath ;; esac ;;
      esac ;;
  esac
  case "$seg" in
    *git*" config"*"$KEY"*)
      post="${seg#*$KEY}"
      case "$seg" in *"--unset"*) deny_hookspath ;; esac
      val=$(printf '%s' "$post" | sed -E "s/^[= ]*//; s/^[\"']//; s/[\"' ].*//")
      case "$val" in ""|.githooks|./.githooks) ;; *) deny_hookspath ;; esac ;;
  esac
done <<SEGS
$(printf '%s' "$lower" | tr ';&|' '\n\n\n')
SEGS
case "$scan" in
  *"git commit"*)
    flags=$(printf '%s' "$scan" | sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')
    # Isolate the `git commit ...` segment so a -n flag from a CHAINED command (e.g. `&& head -n 5`)
    # isn't misread as a commit flag (a rare second chained --no-verify is caught by CI).
    seg=$(printf '%s' "$flags" | sed -E 's/.*git commit//; s/[;&|].*//')
    if printf '%s\n' "$seg" | grep -qE '(--no-verify|(^| )-[^mFcCtOSu= -]*n)'; then
      jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
        permissionDecisionReason:"git commit --no-verify/-n bypasses the commit gate — not allowed. Commit without it; if the message is the problem, fix the message."}}'
      exit 0
    fi ;;
esac
exit 0
