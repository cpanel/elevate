#!/usr/bin/env bash
# lint-workflows.sh — workflow supply-chain lint, shared by spokes and the hub.
# Every external `uses:` must be (1) SHA-pinned and (2) listed in approved-actions.yaml, and every
# job must run on a self-hosted runner (no GitHub-hosted ubuntu/windows/macos labels: paid minutes).
# `pending-security` entries pass with a warning. Non-zero exit gates a PR.
# Exempt from (1) and (2): local (./...) and docker:// refs, and anything the webpros-cpanel org owns
# (its actions and reusable workflows), whose tags the org controls (Case CP2-14). GitHub reads owner
# names case-insensitively, so WebPros-cPanel/... counts too.
#
# Usage: bash lint-workflows.sh [workflows-dir] [approved-actions.yaml]
#        (defaults: .github/workflows  .github/approved-actions.yaml)
set -euo pipefail

wf="${1:-.github/workflows}"
list="${2:-.github/approved-actions.yaml}"

fail=0
err()  { echo "FAIL: $*" >&2; fail=1; }
warn() { echo "warn: $*" >&2; }
ok()   { echo "ok:   $*"; }

[ -f "$list" ] || { echo "FAIL: approved-actions list not found: $list" >&2; exit 1; }

# approved-actions.yaml → "<uses> <status>" lines. Plain awk: the lint stays dependency-free.
approved=$(awk '
  /^[[:space:]]*-[[:space:]]*uses:/ { sub(/^[[:space:]]*-[[:space:]]*uses:[[:space:]]*/, ""); u = $1; next }
  /^[[:space:]]*status:/ && u != "" { print u, $2; u = "" }
' "$list")

shopt -s nullglob
for f in "$wf"/*.yml "$wf"/*.yaml; do
  name="$(basename "$f")"

  while IFS= read -r line; do
    ref="${line#*uses:}"; ref="${ref#"${ref%%[![:space:]]*}"}"   # strip up to and incl. 'uses:', trim
    ref="${ref#[\"\']}"                                          # an optionally quoted ref
    case "$ref" in ./*|docker://*) continue ;; esac
    case "$(printf '%s' "${ref%%/*}" | tr '[:upper:]' '[:lower:]')" in webpros-cpanel) continue ;; esac
    action="${ref%%@*}"
    printf '%s' "$ref" | grep -qE "@[0-9a-f]{40}([[:space:]]|#|$)" \
      || err "$name: action not SHA-pinned: ${ref%% *}"
    status=$(awk -v a="$action" '$1 == a { print $2; exit }' <<<"$approved")
    case "$status" in
      "") err "$name: action not in $(basename "$list"): $action (ask Security, then add it)" ;;
      pending-security) warn "$name: $action is waiting for Security review" ;;
    esac
  done < <(grep -E "^[[:space:]]*-?[[:space:]]*uses:" "$f")

  # One line per runs-on: its one-line value, or a block value (a list, group:, labels:) joined
  # from the deeper lines below it, comments dropped. A ${{ }} value is a choice, not judged here.
  while IFS= read -r label; do
    case "$label" in
      *"\${{"*) continue ;;
      # Quoted halves, so the stamp scripts' sed does not rewrite this pattern itself.
      *__SPOKE_"RUNNER"__*) err "$name: unreplaced runner placeholder (stamp with new-spoke.sh)" ;;
    esac
    if grep -qE '(^|[^A-Za-z0-9_.-])(ubuntu|windows|macos)-[A-Za-z0-9.]+' <<<"$label"; then
      err "$name: GitHub-hosted runner '$(tr -s ' ' <<<"$label" | sed 's/^ //')' — use the org's self-hosted group"
    fi
  done < <(awk '
    function ind(s) { match(s, /^ */); return RLENGTH }
    BEGIN { blk = -1 }
    blk >= 0 {
      if ($0 ~ /^[[:space:]]*(#.*)?$/) next
      if (ind($0) > blk || (ind($0) == blk && $0 ~ /^ *- /)) {
        l = $0; sub(/[[:space:]]+#.*$/, "", l); v = v " " l; next
      }
      print v; blk = -1
    }
    /^[[:space:]]*runs-on:/ {
      val = $0; sub(/^[[:space:]]*runs-on:[[:space:]]*/, "", val)
      sub(/^#.*/, "", val); sub(/[[:space:]]+#.*$/, "", val)
      if (val == "") { blk = ind($0); v = ""; next }
      print val
    }
    END { if (blk >= 0) print v }
  ' "$f")
done

if [ "$fail" -eq 0 ]; then echo "workflow lint: PASS"; else echo "workflow lint: FAIL"; exit 1; fi
