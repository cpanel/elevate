#!/usr/bin/env bash
# lint-workflows.sh — workflow supply-chain lint for a hub and its spokes (engineering-kit-workflow-lint).
# Every external `uses:` must be listed and pinned to a ref that cannot move under us, and every job
# must run on a self-hosted runner (no GitHub-hosted ubuntu/windows/macos labels: paid minutes;
# a label inside a matrix variable is not followed).
# `pending-security` entries pass with a warning, and so does a SHA pin whose comment names only a
# major (`# v4`). Non-zero exit gates a PR.
#
# Which refs pass (KIT.md § Which refs pass):
#   any listed action                               a 40-hex commit SHA
#   first-party (actions/*, github/*)               also a version tag: vN, vN.M or vN.M.P
#   webpros-owned with `tags: protected`            also a version tag (Security confirmed the
#                                                   owning repo protects its v* tags)
#   a reusable workflow (…/.github/workflows/…)     a SHA only, whatever the owner
#   docker://                                       an @sha256: digest only
# A branch (`@main`, `@latest`) never passes. Each list is checked too: a status must agree with the
# owner, so a mislabelled entry cannot grant tag rights.
#
# One opt-in for a repo's OWN org (KIT.md § Own org): a top-level `own-org: <org>` in the LOCAL list,
# naming an org in WEBPROS_ORGS that is the org of the repo being linted (GITHUB_REPOSITORY, else the
# `origin` remote; unreadable fails closed). A `uses:` under that org then needs no entry, and:
#   an own-org action                               a SHA or a version tag
#   an own-org reusable workflow                    any ref — a branch included
#
# Two lists. The SHARED list ships with this kit; Security reviews every change to it. The optional
# LOCAL list is the repo's own: it may add `webpros-owned` and `first-party` entries only — never a
# third-party action, never `tags:`, never an entry the shared list already has.
#
# Usage: bash lint-workflows.sh [workflows-dir] [shared-list] [local-list]
#   defaults: .github/workflows  .github/approved-actions.yaml  .github/approved-actions.local.yaml
#   (the default local list is read only when it exists; a local list named on the command line must exist)
# Call it through `bash`: the kit installer does not keep the executable bit.
set -euo pipefail

wf="${1:-.github/workflows}"
[ -d "$wf" ] || { echo "FAIL: workflows directory not found: $wf" >&2; exit 1; }
list="${2:-.github/approved-actions.yaml}"
if [ -n "${3:-}" ]; then
  local_list="$3"
  [ -f "$local_list" ] || { echo "FAIL: local approved-actions list not found: $local_list" >&2; exit 1; }
elif [ -f .github/approved-actions.local.yaml ]; then
  local_list=.github/approved-actions.local.yaml
else
  local_list=""
fi

# The GitHub orgs WebPros owns, exactly — `webpros-*` would admit an org anyone can register.
# Add an org here only in a PR Security reviews: it widens what `webpros-owned` may name.
WEBPROS_ORGS=" webpros-commerce webpros-cpanel webpros-dashboard webpros-data webpros-integrations
  webpros-internal-platform webpros-plesk webpros-sandbox webpros-security webpros-socialbee
  webpros-solusvm webpros-wordpress "
WEBPROS_ORGS="$(tr -s '[:space:]' ' ' <<<"$WEBPROS_ORGS")"

fail=0
err()  { echo "FAIL: $*" >&2; fail=1; }
warn() { echo "warn: $*" >&2; }

[ -f "$list" ] || { echo "FAIL: approved-actions list not found: $list" >&2; exit 1; }

# A list's top-level `own-org:` values, lower-cased, one per line. An indented key is not top-level
# but is still reported, so a shared list cannot hide one under an entry.
own_org_keys() {
  awk '/^[[:space:]]*own-org[[:space:]]*:/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]#.*$/, "", v)
         gsub(/["\047\r]/, "", v); sub(/[[:space:]]+$/, "", v); print ($0 ~ /^own-org:/ ? "" : "indented ") (v == "" ? "-" : tolower(v)) }' "$1"
}
# The org of the repository being linted, lower-cased: GITHUB_REPOSITORY in CI, else the `origin`
# remote of the current directory. Empty when neither can be read.
repo_org() {
  local r="${GITHUB_REPOSITORY:-}"
  if [ -z "$r" ]; then
    r="$(git remote get-url origin 2>/dev/null || true)"
    r="$(sed -E 's#^(git@[^:]+:|[a-z+]+://([^@/]+@)?[^/]+/)##' <<<"$r")"
  fi
  r="${r%%/*}"; tr '[:upper:]' '[:lower:]' <<<"$r"
}

# A list → "<uses> <status> <tags>" lines ("-" for an absent field). Plain awk: the lint stays
# dependency-free. Quotes and trailing comments are dropped from each value.
parse_list() {
  awk '
    function val(s) { sub(/^[^:]*:[[:space:]]*/, "", s); sub(/[[:space:]]#.*$/, "", s); gsub(/["\047\r]/, "", s)
                      sub(/[[:space:]]+$/, "", s); return s }
    function flush() { if (u != "") print u, (st == "" ? "-" : st), (tg == "" ? "-" : tg); u = st = tg = "" }
    /^[[:space:]]*-[[:space:]]*uses:/ { flush(); u = val($0); next }
    /^[[:space:]]*status:/ && u != "" { st = val($0); next }
    /^[[:space:]]*tags:/   && u != "" { tg = val($0); next }
    END { flush() }
  ' "$1"
}

# A list agrees with itself: a known status, an owner that fits it, `tags:` only where it applies.
# $1 the parsed list, $2 its file name, $3 "local" for the stricter local rules.
check_list() {
  local u st tg owner
  while read -r u st tg; do
    [ -n "$u" ] || continue
    owner="${u%%/*}"
    case "$st" in
      first-party)
        case "$owner" in actions|github) ;; *) err "$2: $u is first-party, but GitHub publishes only actions/* and github/*" ;; esac ;;
      webpros-owned)
        case "$WEBPROS_ORGS" in *" $owner "*) ;; *) err "$2: $u is webpros-owned, but '$owner' is not in WEBPROS_ORGS ($(basename "$0"))" ;; esac ;;
      approved|pending-security)
        [ "$3" = local ] && err "$2: $u is third-party ($st) — only the shared list, which Security reviews, may hold one" ;;
      *) err "$2: $u has unknown status '$st'" ;;
    esac
    case "$tg" in
      -) ;;
      protected)
        if [ "$3" = local ]; then err "$2: $u — 'tags: protected' is granted only in the shared list"
        elif [ "$st" != webpros-owned ]; then err "$2: $u — 'tags: protected' applies only to webpros-owned"; fi ;;
      *) err "$2: $u has unknown tags value '$tg' (only: protected)" ;;
    esac
  done <<<"$1"
}

approved="$(parse_list "$list")"
check_list "$approved" "$(basename "$list")" shared
[ -n "$(own_org_keys "$list")" ] && err "$(basename "$list"): 'own-org' is a repo's own opt-in — only the local list may hold it"
own_org=""
if [ -n "$local_list" ]; then
  keys="$(own_org_keys "$local_list")"
  if [ -n "$keys" ]; then
    if [ "$(wc -l <<<"$keys")" -ne 1 ] || [ "${keys#indented }" != "$keys" ]; then
      err "$(basename "$local_list"): write 'own-org: <org>' once, at the top level"
    elif [ "$keys" = - ] || [ "${keys#* }" != "$keys" ]; then
      err "$(basename "$local_list"): 'own-org' needs one org name"
    else
      case "$WEBPROS_ORGS" in
        *" $keys "*)
          this="$(repo_org)"
          if [ -z "$this" ]; then
            err "$(basename "$local_list"): own-org '$keys' — cannot read this repo's org (set GITHUB_REPOSITORY or an 'origin' remote)"
          elif [ "$this" != "$keys" ]; then
            err "$(basename "$local_list"): own-org '$keys' is not this repo's org ('$this')"
          else
            own_org="$keys"
          fi ;;
        *) err "$(basename "$local_list"): own-org '$keys' is not in WEBPROS_ORGS ($(basename "$0"))" ;;
      esac
    fi
  fi

  local_approved="$(parse_list "$local_list")"
  check_list "$local_approved" "$(basename "$local_list")" local
  while read -r u _; do
    [ -n "$u" ] || continue
    if awk -v a="$u" '$1 == a { found = 1 } END { exit !found }' <<<"$approved"; then
      err "$(basename "$local_list"): $u is already in $(basename "$list") — the shared entry decides"
    fi
  done <<<"$local_approved"
  approved="$approved"$'\n'"$local_approved"
fi
lname="$(basename "$list")${local_list:+ or $(basename "$local_list")}"

shopt -s nullglob dotglob   # a dot-named workflow is checked too
for f in "$wf"/*.yml "$wf"/*.yaml; do
  name="$(basename "$f")"

  # A bare CR, NEL, LS or PS is a line break to YAML but not to grep: no line parser would see it.
  if LC_ALL=C grep -qE $'\r.|\xc2\x85|\xe2\x80[\xa8\xa9]' "$f"; then
    err "$name: a line break the lint cannot see (bare CR, NEL, LS or PS) — save the file with LF line ends"; continue
  fi

  # Fail closed on a key the line parsers below cannot read. Only block style is read:
  #  · a flow value (`- {…}`, `steps: [{…}]`, `build2: {…}`, after any key, anchor or tag) fails
  #    when it names uses or runs-on anywhere, has an escaped key, or does not close on its line;
  #  · a flow continuation line (starting with `{`, `[` or `,`) that has a uses/runs-on key;
  #  · an anchor or tag on a uses/runs-on key (`- !!str uses:`, `&a runs-on:`);
  #  · a quoted or spaced uses/runs-on key, a complex key (`? …`), an escaped "u\x73es" key.
  # Prose that mentions "uses:" in a name is not a key, and a block scalar (`run: |`) is text: skipped.
  while IFS= read -r line; do
    err "$name: cannot read this line — write keys plain, in block style, as '- uses: owner/repo@ref' and 'runs-on: <group>': ${line#"${line%%[![:space:]]*}"}"
  done < <(tr -d '\r' <"$f" | awk '
    function ind(s) { match(s, /^ */); return RLENGTH }
    function closes(s, q) {            # does s close a quoted scalar opened with q?
      if (q == "\"") { gsub(/\\./, "", s); return index(s, "\"") > 0 }
      gsub(/\047\047/, "", s); return index(s, "\047") > 0
    }
    function unbalanced(s,   t, o, c) {
      gsub(/"([^"\\]|\\.)*"|\047([^\047]|\047\047)*\047/, "", s)
      t = s; o = gsub(/[[{]/, "", t); t = s; c = gsub(/[]}]/, "", t); return o != c
    }
    BEGIN {
      ukey  = "[\"\047]?(uses|runs-on)[\"\047]?[[:space:]]*:"
      kname = "([A-Za-z0-9_][A-Za-z0-9_.-]*|\"[^\"]*\"|\047[^\047]*\047)"
      key   = kname "[[:space:]]*:[[:space:]]+"   # a job id or step key; `k:"x` with no blank is a plain scalar
      props = "([&!][^[:space:]]*[[:space:]]+)*"
      under = "^[[:space:]]*(-[[:space:]]+)?" kname "[[:space:]]*:[[:space:]]*" props "(#.*)?$"   # its value on the next line
      fkey  = kname "[[:space:]]*:[[:space:]]*"   # read loosely: it only adds FAILs
      flow  = "^[[:space:]]*(-[[:space:]]+)?(" fkey ")?" props "[[{]"
      # `run: |`, `script: >-`: the lines below, indented deeper than the key, are text, not YAML.
      scalar = "^[[:space:]]*(-[[:space:]]+)*([^#]*[^[:space:]][[:space:]]*:[[:space:]]+)?" props "[|>][-+0-9]*[[:space:]]*(#.*)?$"
      # A quoted value that runs over lines (payload: then a JSON body) is text too, to its closing quote.
      quoted = "^[[:space:]]*(-[[:space:]]+)?" key props "[\"\047]"
      sc = -1; qm = ""
    }
    qm != "" { if (closes($0, qm)) qm = ""; next }
    sc >= 0 { if ($0 ~ /^[[:space:]]*$/ || ind($0) > sc) next; sc = -1 }
    /^[[:space:]]*#/ { next }
    $0 ~ scalar { match($0, /^[[:space:]]*(-[[:space:]]+)*/); sc = RLENGTH; next }
    { p = pend; pend = ($0 ~ under) }
    match($0, quoted) || (p && match($0, "^[[:space:]]*(-[[:space:]]+)?" props "[\"\047]")) {   # a value on the line under its key
      q = substr($0, RSTART + RLENGTH - 1, 1)
      if (!closes(substr($0, RSTART + RLENGTH), q)) { qm = q; next }
    }
    { t = $0; gsub(/"([^"\\]|\\.)*"|\047([^\047]|\047\047)*\047/, "", t)   # any other quote left open: fail
      if (t ~ /(^|[[:space:]:,[{])["\047]/) { print; next } }
    /^[[:space:]]*-?[[:space:]]*(uses|runs-on):/ { next }
    $0 ~ flow {                        # a bare `{` line is a script, not a value: no unbalanced check
      rest = $0; sub(flow, "", rest)
      if (rest ~ /(uses|runs-on)/ || rest ~ /"[^"]*\\[^"]*"[[:space:]]*:/) { print; next }
      if ($0 !~ /^[[:space:]]*[[{]/ && unbalanced("[" rest)) { print; next }
    }
    $0 ~ ("^[[:space:]]*[[{,].*[[{,[:space:]]" ukey) || $0 ~ ("^[[:space:]]*[[{,][[:space:]]*" ukey) { print; next }
    $0 ~ ("^[[:space:]]*(-[[:space:]]+)?([&!][^[:space:]]*[[:space:]]+)+" ukey) { print; next }
    /^[[:space:]]*-?[[:space:]]*(["\047](uses|runs-on)["\047][[:space:]]*|(uses|runs-on)[[:space:]]+):/ { print; next }
    /^[[:space:]]*-?[[:space:]]*\?([[:space:]]|$)/ { print; next }
    /^[[:space:]]*(-[[:space:]]+)?([&!][^[:space:]]*[[:space:]]+)*"[^"]*\\[^"]*"[[:space:]]*:/ { print; next }
    /(^|[[{,])[[:space:]]*(-[[:space:]]+)?\*[^[:space:]]+[[:space:]]*:/ { print; next }   # an alias key (*k : v)
    /(^|[[{,])[[:space:]]*(-[[:space:]]+)?<<[[:space:]]*:/ { print; next }               # a merge key
  ')

  while IFS= read -r line; do
    line="${line%$'\r'}"
    ref="${line#*uses:}"; ref="${ref%%[[:space:]]#*}"                            # drop the key, a comment
    ref="${ref#"${ref%%[![:space:]]*}"}"; ref="${ref%"${ref##*[![:space:]]}"}"   # trim
    case "$ref" in \"*\"|\'*\') ref="${ref:1:${#ref}-2}" ;; esac              # unquote a matched pair
    case "$ref" in
      ./*) continue ;;
      docker://*)
        grep -qE "@sha256:[0-9a-f]{64}$" <<<"$ref" || err "$name: docker image not digest-pinned (@sha256:…): $ref"
        continue ;;
    esac
    action="${ref%@*}"; ver="${ref#*@}"
    if [ "$action" = "$ref" ] || [ "${action#*@}" != "$action" ]; then
      err "$name: cannot read the ref of '$ref' (want owner/repo@ref)"; continue
    fi
    # A SHA pin's comment names its full version. Dependabot rewrites the comment only when it
    # matches the old version exactly, so a bare major (`# v4`) goes stale on the next major bump.
    if grep -qE "^[0-9a-f]{40}$" <<<"$ver"; then
      note=""; case "$line" in *[[:space:]]\#*) note="${line#*[[:space:]]#}" ;; esac
      read -r note _ <<<"$note" || true
      if grep -qE "^v[0-9]+$" <<<"$note"; then
        warn "$name: $action@${ver:0:7} — comment '# $note' names only the major; write the full version (# $note.M.P) so Dependabot keeps it true"
      fi
    fi
    if [ -n "$own_org" ] && [ "$(tr '[:upper:]' '[:lower:]' <<<"${action%%/*}")" = "$own_org" ]; then
      if [[ "$action" == */.github/workflows/* ]]; then
        grep -qE '^[A-Za-z0-9._/-]+$' <<<"$ver" || err "$name: $action@$ver — cannot read this ref"
      elif ! grep -qE "^([0-9a-f]{40}|v[0-9]+(\.[0-9]+){0,2})$" <<<"$ver"; then
        err "$name: $action@$ver — an own-org action takes a SHA or a version tag; only an own-org reusable workflow may follow a branch"
      fi
      continue
    fi
    entry=$(awk -v a="$action" '$1 == a { print $2, $3; exit }' <<<"$approved")
    status="${entry%% *}"; tags="${entry#* }"
    case "$status" in
      "") err "$name: action not in $lname: $action (ask Security, then add it)" ;;
      pending-security) warn "$name: $action is waiting for Security review" ;;
    esac
    grep -qE "^[0-9a-f]{40}$" <<<"$ver" && continue                             # a SHA always passes
    if ! grep -qE "^v[0-9]+(\.[0-9]+){0,2}$" <<<"$ver"; then
      err "$name: $action@$ver — not a SHA or a version tag (a branch moves on every push)"
    elif [[ "$action" == */.github/workflows/* ]]; then
      err "$name: $action@$ver — a reusable workflow must be SHA-pinned, whatever its owner"
    elif [ "$status" = first-party ] || { [ "$status" = webpros-owned ] && [ "$tags" = protected ]; }; then
      :   # a trusted owner's version tag
    elif [ "$status" = webpros-owned ]; then
      err "$name: $action@$ver — SHA-pin it; a tag passes once its shared entry has 'tags: protected'"
    elif [ -n "$status" ]; then
      err "$name: $action@$ver — a third-party action must be SHA-pinned"
    fi
  done < <(grep -E "^[[:space:]]*-?[[:space:]]*uses:" "$f")

  # One line per runs-on: its one-line value, or a block value (a list, group:, labels:) joined
  # from the deeper lines below it, comments dropped. A ${{ }} value is read as text: a literal
  # hosted label inside it fails, a matrix variable is not followed (its values are not checked).
  # A block written as a `- ` list fails even when every label is self-hosted: the stamp scripts
  # substitute the runner with a one-line sed, so a list can never be stamped (paved-road-hub#67).
  while IFS= read -r label; do
    case "$label" in
      __BLOCK_SCALAR__) err "$name: runs-on is a block scalar (| or >) — write the value on the runs-on line"; continue ;;
      __ALIAS__) err "$name: runs-on is a YAML alias (*name) — write the label on the runs-on line"; continue ;;
      __LIST__*)
        err "$name: runs-on written as a '- ' list — the stamp scripts cannot substitute it; use one self-hosted label or a { group: … } block"
        label="${label#__LIST__}" ;;
      # Quoted halves, so the stamp scripts' sed does not rewrite this pattern itself.
      *__SPOKE_"RUNNER"__*) err "$name: unreplaced runner placeholder (stamp with new-spoke.sh)" ;;
    esac
    # An escape ("ubuntu\x2dlatest") or a tag (!!binary …) hides the label from the text match below.
    # A ${{ }} expression is dropped first: its `!` is a negation, not a tag.
    if grep -qE '\\|(^|[[:space:],[])!' <<<"$(sed 's/\$[{][{][^}]*[}][}]//g' <<<"$label")"; then
      err "$name: runs-on uses an escape or a tag — write the label as plain text"; continue
    fi
    if grep -qiE '(^|[^A-Za-z0-9_.-])(ubuntu|windows|macos)-[A-Za-z0-9.]+' <<<"$label"; then
      err "$name: GitHub-hosted runner '$(tr -s ' ' <<<"$label" | sed 's/^ //')' — use the org's self-hosted group"
    fi
  done < <(tr -d '\r' <"$f" | awk '
    function ind(s) { match(s, /^ */); return RLENGTH }
    BEGIN { blk = -1 }
    blk >= 0 {
      if ($0 ~ /^[[:space:]]*(#.*)?$/) next
      if (ind($0) > blk || (ind($0) == blk && $0 ~ /^ *- /)) {
        if (v == "" && $0 ~ /^ *- /) seq = 1
        l = $0; sub(/[[:space:]]+#.*$/, "", l); v = v " " l; next
      }
      print (seq ? "__LIST__" : "") v; blk = -1
    }
    /^[[:space:]]*runs-on:/ {
      val = $0; sub(/^[[:space:]]*runs-on:[[:space:]]*/, "", val)
      sub(/^#.*/, "", val); sub(/[[:space:]]+#.*$/, "", val)
      if (val == "") { blk = ind($0); v = ""; seq = 0; next }
      if (val ~ /^[|>]/) { print "__BLOCK_SCALAR__"; next }
      if (val ~ /^\*/) { print "__ALIAS__"; next }
      print val
    }
    END { if (blk >= 0) print (seq ? "__LIST__" : "") v }
  ')
done

if [ "$fail" -eq 0 ]; then echo "workflow lint: PASS"; else echo "workflow lint: FAIL"; exit 1; fi
