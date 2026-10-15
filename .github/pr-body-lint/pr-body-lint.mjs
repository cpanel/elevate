#!/usr/bin/env node
// pr-body-lint — a pull request must say what it changes, and CI is the thing that says so.
//
// Installed by harness-setup (Artefact 4) as .github/pr-body-lint/pr-body-lint.mjs, beside
// .github/pr-body-lint.json, which the repo owns. Every number lives in that file, never here: a
// threshold in this script would turn every plugin update into a conflict with the repo's own edit.
//
// What counts as written. HTML comments are stripped first, multi-line and unterminated ones
// included, so a template's placeholder prompts are not "filled". Then every line the PR template
// already carries is dropped — headings and checklist rows, with a ticked box read as the unticked
// one. What is left is what the author wrote. Without that second step an untouched template
// passes any length bar: the marketplace's own template is 2,000 characters before anyone types.
//
// Usage:
//   pr-body-lint.mjs check  [--config F] [--format text|github]   body from $PR_BODY, author from $PR_AUTHOR
//   pr-body-lint.mjs replay <prs.json> [--config F]               gh pr list --json number,author,body
//
// Exit codes: 0 pass, 1 the body fails the rule (replay: at least one PR would fail), 2 the config
// is missing or invalid, or a PR template cannot be read.
// No network, no shell, no writes except $GITHUB_STEP_SUMMARY. The body arrives through the
// environment, never interpolated into a script.

import { readFileSync, existsSync, readdirSync, appendFileSync } from "node:fs";
import { join } from "node:path";

export const CONFIG_REL = ".github/pr-body-lint.json";

// Where GitHub looks for a PR template. Every one found is read: lines from all of them count as
// template text, so a repo with several templates gets the same treatment from each.
const TEMPLATE_PATHS = [
  "pull_request_template.md",
  ".github/pull_request_template.md",
  "docs/pull_request_template.md",
];
const TEMPLATE_DIRS = ["PULL_REQUEST_TEMPLATE", ".github/PULL_REQUEST_TEMPLATE", "docs/PULL_REQUEST_TEMPLATE"];

export function stripComments(text) {
  return String(text ?? "").replace(/\r/g, "").replace(/<!--[\s\S]*?(?:-->|$)/g, "");
}

// A line as the comparison sees it: trimmed, inner whitespace collapsed, a ticked box unticked.
function normalise(line) {
  return line.trim().replace(/\s+/g, " ").replace(/^([-*+]) \[[ xX]\]/, "$1 [ ]");
}

/**
 * Every normalised non-blank line of the repo's PR templates. GitHub matches the names case-insensitively.
 * A template directory that does not exist is the normal case; any other read failure throws, so a
 * template the checker cannot open fails the run instead of dropping out of the comparison.
 */
export function templateLines(repoDir) {
  const files = [];
  const lower = (dir) => {
    try { return readdirSync(join(repoDir, dir)); } catch (e) {
      if (e.code === "ENOENT" || e.code === "ENOTDIR") return [];
      throw e;
    }
  };
  for (const rel of TEMPLATE_PATHS) {
    const slash = rel.lastIndexOf("/");
    const dir = slash < 0 ? "" : rel.slice(0, slash);
    const name = rel.slice(slash + 1);
    for (const f of lower(dir || ".")) if (f.toLowerCase() === name) files.push(join(repoDir, dir, f));
  }
  for (const rel of TEMPLATE_DIRS) {
    const slash = rel.lastIndexOf("/");
    const parent = slash < 0 ? "." : rel.slice(0, slash);
    const want = rel.slice(slash + 1).toLowerCase();
    for (const d of lower(parent)) {
      if (d.toLowerCase() !== want) continue;
      for (const f of lower(join(parent, d))) if (f.endsWith(".md")) files.push(join(repoDir, parent, d, f));
    }
  }
  const lines = new Set();
  for (const f of files) {
    for (const l of stripComments(readFileSync(f, "utf8")).split("\n")) {
      const n = normalise(l);
      if (n) lines.add(n);
    }
  }
  return lines;
}

/** Load and validate the repo's config. Throws with a message a person can act on. */
export function loadConfig(path) {
  if (!existsSync(path)) {
    throw new Error(`${path} is missing. The workflow takes every number from it; reinstall with harness-setup.`);
  }
  let c;
  try { c = JSON.parse(readFileSync(path, "utf8")); } catch (e) { throw new Error(`${path} is not valid JSON: ${e.message}`); }
  if (!Number.isInteger(c.minLength) || c.minLength < 0) {
    throw new Error(`${path}: "minLength" must be a whole number, 0 or more.`);
  }
  for (const key of ["requiredSections", "exempt"]) {
    if (c[key] === undefined) c[key] = [];
    if (!Array.isArray(c[key]) || c[key].some((s) => typeof s !== "string" || !s.trim())) {
      throw new Error(`${path}: "${key}" must be a list of non-empty strings.`);
    }
  }
  return c;
}

// The PR event says `dependabot[bot]`; `gh pr list` says `app/dependabot`. Same account.
function sameAuthor(a, b) {
  const canon = (s) => String(s || "").toLowerCase().replace(/^app\/(.+)$/, "$1[bot]");
  return canon(a) === canon(b);
}

/**
 * Judge one body. Returns { ok, exempt, written, problems[] }, where `written` is the count of
 * characters the author wrote — what minLength is measured against.
 */
export function judge(body, { config, template = new Set(), author = "" }) {
  if (config.exempt.some((e) => sameAuthor(e, author))) {
    return { ok: true, exempt: true, written: 0, problems: [] };
  }
  const lines = stripComments(body).split("\n");
  const authored = (l) => {
    const n = normalise(l);
    return n !== "" && !template.has(n);
  };
  const written = lines.filter(authored).map((l) => l.trim()).join("\n").length;
  const problems = [];

  if (written < config.minLength) {
    problems.push(
      written === 0
        ? `The PR description is empty, or is the template left unfilled. Write at least ${config.minLength} characters on what this PR changes and why.`
        : `The PR description has ${written} characters of your own text; this repo asks for at least ${config.minLength}. Say what this PR changes and why.`,
    );
  }

  for (const want of config.requiredSections) {
    const target = want.replace(/^#+\s*/, "").trim().toLowerCase();
    let level = 0, seen = false, filled = false;
    for (const l of lines) {
      const h = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(l.trim());
      if (h) {
        if (level && h[1].length <= level) level = 0;
        if (h[2].toLowerCase() === target) { level = h[1].length; seen = true; }
        continue;
      }
      if (level && authored(l)) filled = true;
    }
    if (!seen) problems.push(`The PR description has no "${want}" section.`);
    else if (!filled) problems.push(`The "${want}" section is empty. Fill it in.`);
  }

  return { ok: problems.length === 0, exempt: false, written, problems };
}

function arg(argv, flag, fallback) {
  const i = argv.indexOf(flag);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback;
}

function main(argv) {
  const [cmd] = argv;
  const repo = process.cwd();
  let config;
  try { config = loadConfig(arg(argv, "--config", join(repo, CONFIG_REL))); } catch (e) {
    console.error(`pr-body-lint: ${e.message}`);
    return 2;
  }
  let template;
  try { template = templateLines(repo); } catch (e) {
    console.error(`pr-body-lint: cannot read the PR template: ${e.message}`);
    return 2;
  }

  if (cmd === "check") {
    const github = arg(argv, "--format", "text") === "github";
    const r = judge(process.env.PR_BODY, { config, template, author: process.env.PR_AUTHOR });
    if (r.exempt) {
      console.log(`pr-body-lint: PASS — ${process.env.PR_AUTHOR} is on the exempt list in ${CONFIG_REL}.`);
      return 0;
    }
    if (r.ok) {
      console.log(`pr-body-lint: PASS — ${r.written} characters written (minimum ${config.minLength}).`);
      return 0;
    }
    const fix = "Edit the PR description. The check re-runs on the edit; no push is needed.";
    for (const p of r.problems) console.log(github ? `::error title=pr-body-lint::${p} ${fix}` : `FAIL: ${p}`);
    if (!github) console.log(fix);
    if (process.env.GITHUB_STEP_SUMMARY) {
      appendFileSync(process.env.GITHUB_STEP_SUMMARY,
        `### pr-body-lint failed\n\n${r.problems.map((p) => `- ${p}`).join("\n")}\n\n${fix}\n`);
    }
    return 1;
  }

  if (cmd === "replay") {
    const file = argv[1];
    if (!file || !existsSync(file)) {
      console.error("usage: pr-body-lint.mjs replay <prs.json>   (gh pr list --state all --limit 100 --json number,author,body)");
      return 2;
    }
    const prs = JSON.parse(readFileSync(file, "utf8"));
    const failed = [];
    for (const pr of prs) {
      const r = judge(pr.body, { config, template, author: pr.author?.login });
      if (!r.ok) failed.push(`#${pr.number} (${pr.author?.login}, ${r.written} chars): ${r.problems.join(" ")}`);
    }
    console.log(`pr-body-lint replay: ${failed.length} of ${prs.length} PRs would fail.`);
    for (const f of failed) console.log(`  ${f}`);
    return failed.length ? 1 : 0;
  }

  console.error("usage: pr-body-lint.mjs check [--config F] [--format text|github] | replay <prs.json> [--config F]");
  return 2;
}

if (process.argv[1] && process.argv[1].endsWith("pr-body-lint.mjs")) process.exit(main(process.argv.slice(2)));
