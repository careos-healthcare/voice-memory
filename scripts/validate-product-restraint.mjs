#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "app/safety",
  "app/privacy",
  "app/terms",
  "app/contact",
  "app/launch",
  "app/welcome",
  "app/how-it-works",
  "app/privacy-simple",
  "lib/debug",
  "lib/validation",
  "lib/intentions",
  "lib/marketing",
  "lib/social-proof",
  "lib/sharing",
  "lib/memory/memory-compounding.ts",
  "lib/memory/slow-realizations.ts",
  "lib/refinement/revisit-sequencing.ts",
  "lib/refinement/durable-callbacks.ts",
  "lib/archive/",
  "lib/research/",
  "lib/monetization/",
  "lib/pilot/",
  "lib/integrity/",
  "lib/identity/",
  "lib/restraint/",
  "lib/refinement/callback-deduplication.ts",
  "lib/refinement/anti-template.ts",
  "lib/refinement/rarity-preservation.ts",
  "lib/refinement/permanent-callbacks.ts",
  "lib/roundups/roundup-quality.ts",
  "lib/roundups/roundup-observation.ts",
  "lib/tester-onboarding-copy.ts",
  "lib/patterns/pattern-engine.ts",
  "lib/patterns/continuity-engine.ts",
  "lib/retention-metrics.ts",
  "lib/retention/retention-loops.ts",
  "lib/launch-checklist.ts",
  "lib/conversation/followup-prompts.ts",
  "lib/trust-copy.ts",
  "scripts/",
];

/** Canonical header nav — update deliberately when adding essential routes. */
const ESSENTIAL_NAV_HREFS = new Set([
  "/",
  "/memory",
  "/timeline",
  "/weekly",
  "/monthly",
  "/seasons",
  "/bookmarks",
  "/threads",
  "/reminders",
  "/pricing",
  "/demo",
  "/launch",
  "/settings",
  "/account",
  "/archive",
  "/export",
  "/search",
  "/journal",
]);

const ALLOWED_LINK_PREFIXES = [
  "/",
  "/memory",
  "/timeline",
  "/weekly",
  "/monthly",
  "/seasons",
  "/bookmarks",
  "/threads",
  "/reminders",
  "/pricing",
  "/settings",
  "/account",
  "/archive",
  "/export",
  "/search",
  "/journal",
  "/roundups",
  "/intentions",
  "/privacy",
  "/terms",
  "/safety",
  "/contact",
  "/welcome",
  "/how-it-works",
  "/privacy-simple",
  "/entry/",
  "/demo",
  "/#",
];

const FORBIDDEN_LINK_PREFIXES = [
  "/dashboard",
  "/coach",
  "/analytics",
  "/achievements",
  "/insights-engine",
  "/performance",
  "/debug/",
];

const BANNED_PHRASES = [
  { re: /\bdashboard\b/i, label: "dashboard" },
  { re: /\bcoach\b/i, label: "coach" },
  { re: /\bAI coach\b/i, label: "AI coach" },
  { re: /\bassistant\b/i, label: "assistant" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\boptimize\b/i, label: "optimize" },
  { re: /\btherapy bot\b/i, label: "therapy bot" },
  { re: /\bmental health diagnosis\b/i, label: "mental health diagnosis" },
  { re: /\bperformance score\b/i, label: "performance score" },
  { re: /\bgamified\b/i, label: "gamified" },
  { re: /\bachievement\b/i, label: "achievement" },
  { re: /\bstreak badge\b/i, label: "streak badge" },
  { re: /\banalytics dashboard\b/i, label: "analytics dashboard" },
  { re: /\binsight engine\b/i, label: "insight engine" },
  { re: /\bpattern engine\b/i, label: "pattern engine" },
  { re: /\baction plan\b/i, label: "action plan" },
  { re: /\bgoal dashboard\b/i, label: "goal dashboard" },
  { re: /\bproductivity score\b/i, label: "productivity score" },
  { re: /\bhabit completion\b/i, label: "habit completion" },
  { re: /\bkpi\b/i, label: "KPI" },
  { re: /\bsmart goal\b/i, label: "SMART goal" },
  { re: /\bcoaching plan\b/i, label: "coaching plan" },
];

const CHART_DASHBOARD_PHRASES = [
  { re: /\b(?:bar|line|pie|area)\s+chart\b/i, label: "chart wording" },
  { re: /\bdata visualization\b/i, label: "data visualization" },
  { re: /\bmetrics dashboard\b/i, label: "metrics dashboard" },
  { re: /\bretention dashboard\b/i, label: "retention dashboard" },
  { re: /\bkpi\b/i, label: "KPI wording" },
  { re: /\bscoreboard\b/i, label: "scoreboard" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
const MAX_CARDS_PER_PAGE = 4;
const SITE_HEADER = path.join(ROOT, "components", "SiteHeader.tsx");

function shouldSkip(filePath) {
  const rel = path.relative(ROOT, filePath);
  return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (shouldSkip(full)) continue;
    const stat = fs.statSync(full);
    if (stat.isDirectory()) walk(full, out);
    else if (EXT.has(path.extname(name))) out.push(full);
  }
  return out;
}

function isCommentLine(trimmed) {
  return (
    trimmed.startsWith("//") ||
    trimmed.startsWith("*") ||
    trimmed.startsWith("/*") ||
    trimmed.endsWith("*/")
  );
}

function isValidationScriptLine(trimmed) {
  return (
    trimmed.includes("validate:restraint") ||
    trimmed.includes("validate:quiet-copy") ||
    trimmed.includes("validate-product-restraint")
  );
}

function pushViolation(violations, filePath, lineNo, rule, detail, line) {
  violations.push({
    filePath,
    lineNo,
    rule,
    detail,
    line: line.trim().slice(0, 120),
  });
}

function checkBannedPhrases(content, filePath, violations) {
  const lines = content.split("\n");
  lines.forEach((line, i) => {
    const trimmed = line.trim();
    if (!trimmed || isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of BANNED_PHRASES) {
      if (re.test(line)) {
        pushViolation(violations, filePath, i + 1, "banned phrase", label, line);
      }
    }
  });
}

function checkChartDashboardWording(content, filePath, violations) {
  const isUserPage =
    filePath.includes(`${path.sep}app${path.sep}`) &&
    filePath.endsWith("page.tsx") &&
    !filePath.includes(`${path.sep}debug${path.sep}`);

  if (!isUserPage) return;

  const lines = content.split("\n");
  lines.forEach((line, i) => {
    const trimmed = line.trim();
    if (!trimmed || isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of CHART_DASHBOARD_PHRASES) {
      if (re.test(line)) {
        pushViolation(violations, filePath, i + 1, "chart/dashboard wording", label, line);
      }
    }
  });
}

function extractHrefLiterals(content) {
  const hrefs = [];
  const re = /href=["'{`]([^"'`#]+)["'`}]/g;
  let match;
  while ((match = re.exec(content)) !== null) {
    hrefs.push(match[1]);
  }
  return hrefs;
}

function isAllowedProductLink(href) {
  if (FORBIDDEN_LINK_PREFIXES.some((prefix) => href.startsWith(prefix))) return false;
  return ALLOWED_LINK_PREFIXES.some((prefix) => href === prefix || href.startsWith(prefix));
}

function checkSiteHeaderNav(content, filePath, violations) {
  if (filePath !== SITE_HEADER) return;

  const hrefs = extractHrefLiterals(content);
  for (const href of hrefs) {
    if (href === "/") continue;
    if (!ESSENTIAL_NAV_HREFS.has(href)) {
      pushViolation(
        violations,
        filePath,
        0,
        "non-essential nav",
        `unexpected header link: ${href}`,
        `<Link href="${href}">`,
      );
    }
  }

  for (const essential of ESSENTIAL_NAV_HREFS) {
    if (essential === "/") continue;
    if (!hrefs.includes(essential)) {
      pushViolation(
        violations,
        filePath,
        0,
        "nav regression",
        `missing essential header link: ${essential}`,
        `<Link href="${essential}">`,
      );
    }
  }
}

function checkPageNavLinks(content, filePath, violations) {
  const isUserPage =
    filePath.includes(`${path.sep}app${path.sep}`) &&
    filePath.endsWith("page.tsx") &&
    !filePath.includes(`${path.sep}debug${path.sep}`);

  if (!isUserPage || filePath === SITE_HEADER) return;

  const hrefs = extractHrefLiterals(content);
  for (const href of hrefs) {
    if (href.startsWith("http")) continue;
    if (isAllowedProductLink(href)) continue;
    pushViolation(
      violations,
      filePath,
      0,
      "non-essential nav",
      `product page links to non-essential route: ${href}`,
      `<Link href="${href}">`,
    );
  }
}

function checkDenseCardSections(content, filePath, violations) {
  const isUserPage =
    filePath.includes(`${path.sep}app${path.sep}`) &&
    filePath.endsWith("page.tsx") &&
    !filePath.includes(`${path.sep}debug${path.sep}`);

  if (!isUserPage) return;

  const cardCount = (content.match(/<Card[\s>]/g) ?? []).length;
  const gridCardSection = /<div[^>]*className="[^"]*grid-cols-(?:3|4)[^"]*"[^>]*>[\s\S]{0,400}<Card[\s>]/i.test(
    content,
  );

  if (cardCount > MAX_CARDS_PER_PAGE) {
    pushViolation(
      violations,
      filePath,
      0,
      "dense cards",
      `${cardCount} Card sections (max ${MAX_CARDS_PER_PAGE})`,
      "<Card …>",
    );
  } else if (gridCardSection && cardCount >= 3) {
    pushViolation(
      violations,
      filePath,
      0,
      "dense cards",
      "grid of cards on user-facing page",
      'className="…grid-cols-…" with Card',
    );
  }
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const content = fs.readFileSync(file, "utf8");
  checkBannedPhrases(content, file, violations);
  checkChartDashboardWording(content, file, violations);
  checkSiteHeaderNav(content, file, violations);
  checkPageNavLinks(content, file, violations);
  checkDenseCardSections(content, file, violations);
}

if (violations.length > 0) {
  console.error(`validate:restraint failed — ${violations.length} issue(s):\n`);
  for (const v of violations.slice(0, 40)) {
    const rel = path.relative(ROOT, v.filePath);
    const loc = v.lineNo > 0 ? `${rel}:${v.lineNo}` : rel;
    console.error(`  ${loc}  [${v.rule}] ${v.detail}`);
    if (v.line) console.error(`    ${v.line}`);
  }
  if (violations.length > 40) {
    console.error(`  … and ${violations.length - 40} more`);
  }
  process.exit(1);
}

console.log(`validate:restraint passed (${files.length} files scanned)`);
