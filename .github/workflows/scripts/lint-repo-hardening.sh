#!/usr/bin/env bash
# lint-repo-hardening.sh — CI lint for the supply-chain + platform-hardening pillars.
# Re-checks the invariants that keep "merge green = safe" true: a committed lockfile, fail-closed
# installs, least-privilege, SHA-pinned and approved workflows on self-hosted runners, and the
# platform files (CODEOWNERS, SECURITY.md, Dependabot). Security invariants are hard failures;
# adoption checks (placeholders, digest-pinning) warn until SPOKE_ADOPTED=1. Non-zero exit gates a PR.
set -euo pipefail

fail=0
err()  { echo "FAIL: $*" >&2; fail=1; }
warn() { echo "warn: $*" >&2; }
ok()   { echo "ok:   $*"; }

# One repo-wide adoption flag: SPOKE_ADOPTED.
adopted="${SPOKE_ADOPTED:-0}"
wf=".github/workflows"

# ── 1. Reproducible installs ─────────────────────────────────────────────────
# A lockfile is owed per dependency manifest the repository carries: package.json needs
# package-lock.json (Node), pyproject.toml needs uv.lock (Python), pom.xml needs lockfile.json
# (Maven, via io.github.chains-project:maven-lockfile) or a pom pinned as below. A repository with
# none of the three installs nothing through a package manager (a Perl tree built on cPanel's own
# Perl, say), so there is nothing to lock and the check passes.
#
# Maven without that plugin has no lockfile, and mostly needs none: it has no `^1.2.3` range
# semantics to resolve, so a pom declaring neither a version range nor a SNAPSHOT dependency pins
# its direct graph exactly, and released artifacts are immutable. That equivalence is what the
# pom.xml branch below checks, and it is deliberately weaker than a lockfile — it says nothing
# about the transitive closure, and nothing about a source (jitpack, say) that rebuilds an
# artifact from a git ref. A spoke wanting that guarantee adopts maven-lockfile and commits
# lockfile.json, which takes the first branch.
#
# Scanned regions are <properties> and the inside of each <dependency>, <plugin> and <parent>
# element. A module's own <version> belongs to none of those, so a project legitimately versioned
# 1.2.3-SNAPSHOT is not mistaken for a SNAPSHOT dependency. Scanning from <dependencies> to EOF
# instead would be wrong: Maven does not enforce element order, so a pom may declare its own
# <version> below its <dependencies>, and that version would then be read as a dependency's.
#
# Known limit: this is line-oriented, so a pom written entirely on one line puts the project's own
# <version> in the same line as its <dependency> elements and reads it as a dependency's. That fails
# a pom it should pass, which is over-strict rather than unsafe, and no pom a build tool wrote looks
# like that. Parsing XML properly is the fix if one ever does.
manifests=0
if [ -f package.json ]; then
  manifests=1
  if [ -f package-lock.json ]; then ok "package.json locked by package-lock.json"
  else err "package.json has no package-lock.json — installs can't run reproducibly (commit it)"; fi
fi
if [ -f pyproject.toml ]; then
  manifests=1
  if [ -f uv.lock ]; then ok "pyproject.toml locked by uv.lock"
  else err "pyproject.toml has no uv.lock — installs can't run reproducibly (commit it: uv lock)"; fi
fi
if [ -f pom.xml ]; then
  manifests=1
  if [ -f lockfile.json ]; then
    ok "pom.xml locked by lockfile.json"
  else
    unpinned=$(awk '
      /<properties>/                            { inprops = 1 }
      /<dependency>|<plugin>|<parent>/          { indep   = 1 }
      (inprops || indep) && /SNAPSHOT/          { print "  SNAPSHOT: " $0 }
      (inprops || indep) && /<version>[[:space:]]*[\[(]/ { print "  range:    " $0 }
      # Closing rules last, so a one-line <dependency>...</dependency> is still scanned.
      /<\/properties>/                          { inprops = 0 }
      /<\/dependency>|<\/plugin>|<\/parent>/     { indep   = 0 }
    ' pom.xml)
    if [ -n "$unpinned" ]; then
      err "pom.xml is not reproducibly pinned (no lockfile, and these resolve at build time):"
      printf '%s\n' "$unpinned" >&2
    else
      ok "no lockfile, but pom.xml declares no version range and no SNAPSHOT dependency"
    fi
  fi
fi
[ "$manifests" = 1 ] || ok "no dependency manifest (package.json, pyproject.toml, pom.xml) — nothing to lock"

# No silent non-reproducible fallback anywhere.
if grep -qE "npm ci[[:space:]]*\|\|[[:space:]]*npm install" "$wf"/*.yml "$wf"/*.yaml 2>/dev/null; then
  err "found 'npm ci || npm install' fallback — use plain 'npm ci' (fail closed)"
else
  ok "no npm ci/install fallback"
fi

# ── 2. Workflow hygiene: least-privilege token + SHA-pinned, approved actions ──
shopt -s nullglob
for f in "$wf"/*.yml "$wf"/*.yaml; do
  grep -qE "^permissions:" "$f" \
    || err "$(basename "$f"): no top-level 'permissions:' block (least-privilege token)"
done
# SHA pins (the webpros-cpanel org's own refs exempt), the approved-actions list and self-hosted
# runners live in one script, shared with the hub.
# A spoke keeps the stamped defaults; the hub template points WORKFLOW_LINT / APPROVED_ACTIONS at
# kits/workflow-lint/ so it lints itself with the kit's lint and list (repo-hardening-lint.yml).
WORKFLOW_LINT="${WORKFLOW_LINT:-$(dirname "$0")/lint-workflows.sh}"
APPROVED_ACTIONS="${APPROVED_ACTIONS:-.github/approved-actions.yaml}"
bash "$WORKFLOW_LINT" "$wf" "$APPROVED_ACTIONS" \
  || err "workflow lint failed (see above)"

# ── 3. Platform files exist ──────────────────────────────────────────────────
# CODEOWNERS and SECURITY.md live wherever GitHub reads them: .github/, the root, or docs/, first
# match wins. A second copy is never read by GitHub, so it is dead weight that drifts — flag it.
home() {  # $1 file name — print every location present, in GitHub's lookup order
  for d in .github/ "" docs/; do [ -f "$d$1" ] && echo "$d$1"; done
  return 0
}
platform_files=""
for p in CODEOWNERS SECURITY.md; do
  found=$(home "$p")
  if [ -z "$found" ]; then
    err "missing platform file: $p (.github/$p, $p or docs/$p)"
  else
    live=$(printf '%s\n' "$found" | head -1)
    ok "present: $live"
    platform_files="$platform_files $live"
    extra=$(printf '%s\n' "$found" | tail -n +2 | tr '\n' ' ')
    [ -z "$extra" ] || warn "second copy of $p GitHub never reads: ${extra% } (the live one is $live)"
  fi
done
if [ -f .github/dependabot.yml ]; then ok "present: .github/dependabot.yml"; else err "missing platform file: .github/dependabot.yml"; fi
# CONTRIBUTING.md is read from the same three homes; it is recommended, never gated.
found=$(home CONTRIBUTING.md)
if [ -z "$found" ]; then
  warn "no CONTRIBUTING.md (.github/, the root or docs/; recommended, not gated)"
else
  ok "present: $(printf '%s\n' "$found" | head -1)"
fi

# ── 4. Production Dockerfile — non-root + digest-pinned base ──────────────────
if [ -f Dockerfile ]; then
  # `|| true`: no USER line makes grep exit 1, and pipefail would stop the lint here, silently.
  last_user=$(grep -iE "^[[:space:]]*USER[[:space:]]+" Dockerfile | tail -1 | awk '{print $2}' || true)
  case "${last_user:-}" in
    ""|root|0)
      # A root ENTRYPOINT that drops to an unprivileged user before any long-running process is
      # accepted, but only when it is declared AND verifiable: the Dockerfile carries the marker
      # `# hardening: root-entrypoint-drops-privileges <script>`, and that script execs gosu or
      # su-exec (a PaaS volume that mounts root:root needs the root step). Anything else fails.
      ep=$(grep -oE "^#[[:space:]]*hardening:[[:space:]]*root-entrypoint-drops-privileges[[:space:]]+[^[:space:]]+" Dockerfile | awk '{print $NF}' | head -1 || true)
      if [ -n "$ep" ] && [ -f "$ep" ] && grep -qE "exec[[:space:]]+(gosu|su-exec)[[:space:]]" "$ep"; then
        ok "Dockerfile ends on USER root by declaration; $ep drops privileges (gosu/su-exec) before any process runs"
      else
        err "Dockerfile: must end on a non-root USER (found: '${last_user:-none}')"
      fi ;;
    *) ok "Dockerfile runs non-root (USER ${last_user})" ;;
  esac
  last_from=$(grep -iE "^[[:space:]]*FROM[[:space:]]+" Dockerfile | tail -1)
  if ! grep -qF "@sha256:" <<<"$last_from"; then
    if [ "$adopted" = "1" ]; then err "Dockerfile: base image must be digest-pinned (FROM ...@sha256:...)"
    else warn "Dockerfile: base image tag-pinned — digest-pin on adoption, then set SPOKE_ADOPTED=1"; fi
  else
    ok "Dockerfile base image is digest-pinned"
  fi
else
  warn "no production Dockerfile at repo root (recommended for a deployable service)"
fi

# ── 5. Adoption checks — unreplaced placeholders in platform files ────────────
# shellcheck disable=SC2086 # platform_files is a space-separated list of paths without spaces
ph=$(grep -nE '<[a-z0-9._@/-]+>' $platform_files /dev/null 2>/dev/null || true)
if [ -n "$ph" ]; then
  if [ "$adopted" = "1" ]; then echo "$ph" >&2; err "unreplaced <placeholders> in platform files (SPOKE_ADOPTED=1)"
  else warn "unreplaced <placeholders> in CODEOWNERS/SECURITY.md — fill on adoption, then set SPOKE_ADOPTED=1"; fi
fi

if [ "$fail" -eq 0 ]; then echo "repo-hardening lint: PASS"; else echo "repo-hardening lint: FAIL"; exit 1; fi
