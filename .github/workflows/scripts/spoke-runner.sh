#!/usr/bin/env bash
# spoke-runner.sh — the self-hosted `runs-on:` value for a GitHub org. Sourced by new-spoke.sh and
# stamp-additive.sh to fill the runner placeholder; never a GitHub-hosted runner (paid minutes).
#   spoke_runner <org>        → prints the runs-on value, or returns 1 for an unknown org
#   spoke_runner_orgs         → prints the orgs spoke_runner knows, space-separated
#   spoke_org_from_remote DIR → prints the org of DIR's `origin` remote, or nothing
# Add an org here once its runner is verified in a real run: the jobs API (`runner_group_name`) or the
# run log ("Runner group name"). Each row names that evidence as <repo> <run id> (checked 2026-09-30).
# One form for every org: the one-line flow mapping `{ group: <name> }`, where <name> is the
# `runner_group_name` of that evidence run — never a bare scale-set label (where an org's runner group and
# its ARC scale set share a name, the group is the one written). Every pool below runs jobs with no `container:`.
# These are the per-org pools PDX calls legacy: the runner catalog (webpros-internal-platform/
# k8s-clusters-on-prem, runners/catalog.yaml) retires them in its Phase 2, one group at a time. A
# retired or ungranted pool does not fail a job, it leaves it queued — watch a new spoke's first run.
# Spokes get a copy of this file with the rest of common/; the hub's copy is the one that counts.

spoke_runner() {
  case "${1:-}" in
    webpros-sandbox)           echo "{ group: webpros-sandbox }" ;;                 # paved-road-hub 36790507693
    webpros-cpanel)            echo "{ group: org/webpros-cpanel-arc-runners }" ;;  # cpanel-whm 36789482879
    webpros-commerce)          echo "{ group: whmcs-actions-docker }" ;;            # whmcs-application 36757154583
    webpros-dashboard)         echo "{ group: webpros-dashboard }" ;;                          # business-platform 36767234402
    webpros-plesk)             echo "{ group: webpros-plesk }" ;;                              # ext-rest-api 36776346699
    webpros-data)              echo "{ group: webpros-data }" ;;                    # lm-panel-hub 36785880939
    webpros-integrations)      echo "{ group: webpros-integrations }" ;;                       # nova 36766708794
    webpros-internal-platform) echo "{ group: webpros-internal-platform }" ;;                  # wsp-cp 36111523938
    webpros-wordpress)         echo "{ group: webpros-wordpress }" ;;                          # wp-cli-toolkit-command 36687822124
    # No org-wide self-hosted pool is verified for these, so they stay unknown (the stamp stops):
    #   webpros-licensing, webpros-restricted, webpros-archive: GitHub-hosted runners only.
    #   webpros-360-monitoring: only production/staging deploy runners.
    #   webpros-solusvm: per-repo runners (solusnxt, solusvm-docs); dal-enterprise-1 only for Dependabot.
    #   webpros-socialbee: only its .github repo uses dal-enterprise-4 (a title check, a containerised job).
    #   webpros-it, webpros-xovi: a bare `self-hosted` label on ops and deploy hosts, not a CI pool.
    #   webpros-comet: `[self-hosted, linux, x64]` VMs shared by several agents; real CI runs in containers.
    #   webpros-integrations' arc-cpanel-plugins-group is cpanel-plugins' own set and needs `container:`.
    *) return 1 ;;
  esac
}

spoke_runner_orgs() {  # kept equal to the case arms above by tests/test-spoke-runner.sh
  echo "webpros-sandbox webpros-cpanel webpros-commerce webpros-dashboard webpros-plesk webpros-data" \
       "webpros-integrations webpros-internal-platform webpros-wordpress"
}

spoke_org_from_remote() {
  local url
  url="$(git -C "${1:-.}" remote get-url origin 2>/dev/null)" || return 0
  url="${url%.git}"; url="${url#*github.com[:/]}"
  echo "${url%%/*}"
}
