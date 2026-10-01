# ELevate — architecture

> The human doc. Agents read `CLAUDE.md` (and `AGENTS.md`, a link to it); this page is for people.
> The public user documentation is the Hugo site built from `docs-website-src/`.

## What it does

ELevate upgrades the operating system under a running cPanel & WHM server in place, and leaves the
product working afterwards. It wraps the [Leapp project](https://leapp.readthedocs.io/en/latest/)
on RHEL-family systems and `do-release-upgrade` on Ubuntu, and adds the cPanel-specific work around
them: blockers checked before anything changes, components preserved across the upgrade and
restored after it, and a five-stage run that survives the reboots between stages.

| Source | Target |
|---|---|
| CentOS 7 | AlmaLinux 8 |
| CloudLinux 7 | CloudLinux 8 |
| CloudLinux 8 | CloudLinux 9 |
| AlmaLinux 8 | AlmaLinux 9 |
| AlmaLinux 9 | AlmaLinux 10 |
| Ubuntu 20.04 | Ubuntu 22.04 |
| Ubuntu 22.04 | Ubuntu 24.04 |

The sources are `SUPPORTED_DISTROS` in `lib/Elevate/OS.pm`; each `lib/Elevate/OS/<Distro>.pm`
names its target and the minimum cPanel & WHM version it needs.

## How it is built

- `script/elevate-cpanel.PL` is the entry point (the `cpev` package: option parsing, the stages).
- `lib/Elevate/` holds the modules: `OS/` (one class per source distribution), `PkgMgr/` (yum,
  dnf, apt), `Components/` (one class per blocker or preserved component), `Leapp.pm`, `Stages.pm`
  and `StageFile.pm` (the stage number and the state carried across reboots), `Service.pm` (the
  systemd unit), `Logger.pm`, `Script.pm` (the self-update check).
- `make build` fat-packs the entry point and every module into the committed `elevate-cpanel`
  with `maint/perlpkg.static`, stamps `VERSION` from the `version` file and runs `perltidy`. The
  script runs on the product's Perl (`/usr/local/cpanel/3rdparty/perl/536/bin/perl`). Never edit
  `elevate-cpanel` by hand; edit `lib/` or `script/` and rebuild.

## The run

`/scripts/elevate-cpanel --check` runs every blocker in `lib/Elevate/Components/` and writes the
result to `/var/cpanel/elevate-blockers`. `--start` runs the same checks, then installs the
`elevate-cpanel.service` unit, which drives five stages across the reboots:

| Stage | What it does |
|---|---|
| 1 | installs the service that carries the run across reboots |
| 2 | updates the current distribution's packages, then reboots |
| 3 | prepares the cPanel packages, removes known conflicts, then runs the distribution upgrade (Leapp or `do-release-upgrade`) |
| 4 | on the upgraded OS: updates cPanel & WHM for it and restores what stage 3 removed |
| 5 | final checks and cleanup; removes the service |

The stage number and the state between stages live under `/var/cpanel/elevate`; the log is
`/var/log/elevate-cpanel.log`. `--status`, `--log` and `--continue` read and resume a run.

## Upstreams and downstreams

- **Calls:** Leapp and its `elevate-release` repository on RHEL-family systems,
  `do-release-upgrade` on Ubuntu, the distribution's package manager, and cPanel & WHM's own
  scripts (`/usr/local/cpanel/scripts/check_cpanel_pkgs`, `/scripts/restartsrv_*`).
- **Called by:** administrators on the server, and cPanel & WHM: `Cpanel::Elevate` downloads the
  script from the `release` tag and runs its blocker check, and the Security Advisor's ELevate
  assessor reports the result.

## Runbook

- **Test:** `make test` (syntax-checks every module, then `prove` and `yath` over `t/`). CI runs
  the `unit-tests` and `cplint` jobs on every pull request; both are required on `main`. The
  seven `openstack-<distro>.yml` workflows run one real upgrade per source distribution.
- **Release:** `make release` builds, moves the `release` tag, tags `v<version>`, pushes `main` and
  the tags to the public `cpanel/elevate` (the `pub` remote), then bumps `version`. The script's
  self-update reads `https://raw.githubusercontent.com/cpanel/elevate/release/`.
- **Branch protection:** the org's rulesets on `main`, edited in the org's settings; the repository
  carries no ruleset of its own.
- **Security:** `.github/SECURITY.md`.
