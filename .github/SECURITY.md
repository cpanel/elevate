# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities **privately** — do not open a public issue or pull request, here
or on the public mirror `cpanel/elevate`.

- **Preferred:** GitHub private vulnerability reporting (this repository → **Security** → **Report
  a vulnerability**).
- **Or:** cPanel's security disclosure process at <https://cpanel.net/security/>.

Include the ELevate version (`/scripts/elevate-cpanel --version`, or the `version` file) or commit,
the source and target distribution, reproduction steps, and impact.

## Scope

This repository and the `elevate-cpanel` script it builds and publishes through the `release` tag
of `cpanel/elevate`. The cPanel & WHM product being upgraded, and the upgrade tools ELevate drives
(Leapp, `do-release-upgrade`), are covered by their own disclosure processes.

## Supported versions

Only the latest release is supported: `elevate-cpanel` checks that it is the release on the
`release` tag before it starts (`--update` fetches that copy), so security fixes land on `main`
and ship with the next `make release`. Committed secrets are caught by `secret-scan`, and GitHub
Actions versions are kept current by `.github/dependabot.yml`.
