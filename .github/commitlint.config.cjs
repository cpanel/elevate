// cPanel/WHM commit-flavour enforcement — the declarative rule set of record.
// Used by CI (.github/workflows/commitlint.yml via wagoid/commitlint-github-action), which is the
// AUTHORITATIVE commit gate. The local .githooks/commit-msg is a Node-free bash approximation for
// fast feedback (no Node toolchain needed); the two rule sets are kept in sync by hand — if they
// ever diverge, CI wins. Mirrors .githooks/commit-msg's three rules and their levels exactly (this
// repository's last 200 non-merge commits, 2026-09-30 — see that file's header for the numbers);
// the team keeps every rule at warning (severity 1), never an error — a warning-level commitlint
// rule reports but does not fail the CI job, same as the local hook.
// .cjs so it loads as CommonJS even if a host package.json ever sets "type": "module".

// Case number pattern shared by both cpanel rules below, kept in one place so the two can't drift
// apart from each other the way the old bash/JS pair once could. A Jira project key starts with a
// letter and may carry digits (CP2-14), so the key is [A-Z][A-Z0-9_]+, never [A-Z]+.
// In the summary a key is a whole word (a hyphen stays inside its word, so Net-CIDR-0.27 and the
// year in CVE-2026-3381 are not keys), and NOT_A_CASE_RE drops the key-shaped words that never
// are one — the same split and list as the cpanel v2 gate in .githooks/commit-msg (NOT_A_CASE).
const CASE_WORD_RE = /^[A-Z][A-Z0-9_]+-[0-9]+$/;
const NOT_A_CASE_RE = /^(ADR|CVE|CWE|UTF)-[0-9]+$/;
const caseKeys = (header) =>
  header.split(/[^A-Za-z0-9_-]+/).filter((w) => CASE_WORD_RE.test(w) && !NOT_A_CASE_RE.test(w));
const CASE_BODY_LINE_RE = /^Case [A-Z][A-Z0-9_]+-[0-9]+:/m;

module.exports = {
  plugins: [
    {
      rules: {
        // Mirrors .githooks/commit-msg LEVEL_NO_CASE_IN_SUBJECT.
        "cpanel-no-case-in-subject": (parsed) => {
          const header = parsed.header || "";
          const keys = caseKeys(header);
          return [keys.length === 0, `the summary line must not carry a case number (${keys.join(" ")}) — move it to the body: Case CPANEL-1234: <what and why>`];
        },
        // Mirrors .githooks/commit-msg LEVEL_BODY_CASE_LINE. Required for PR-bound work,
        // skippable for a quick direct-to-main fixup — this rule can't tell which a given commit
        // is, so it warns either way rather than blocking.
        "cpanel-case-in-body": (parsed) => {
          const body = parsed.body || "";
          return [CASE_BODY_LINE_RE.test(body), "no 'Case XXX-1234:' line in the body — add one for PR-bound work (third line: Case CPANEL-1234: <what changed, why, what was rejected>); skippable for a direct-to-main fixup"];
        },
      },
    },
  ],
  rules: {
    // Footer trailers (Changelog:, Co-Authored-By:) run long.
    "footer-max-line-length": [2, "always", 200],
    "cpanel-no-case-in-subject": [1, "always"],
    "cpanel-case-in-body": [1, "always"],
    // Mirrors .githooks/commit-msg LEVEL_SUBJECT_LENGTH / SUBJECT_MAX.
    "header-max-length": [1, "always", 50],
  },
};
