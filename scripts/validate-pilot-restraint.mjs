#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/pilot/",
  "lib/monetization/",
  "lib/subscription.ts",
  "components/billing/",
  "app/pricing/",
  "scripts/",
];

const FORBIDDEN_PILOT_PHRASES = [
  { re: /\bfomo\b/i, label: "FOMO" },
  { re: /\bfear of missing\b/i, label: "fear of missing" },
  { re: /\bact now\b/i, label: "act now" },
  { re: /\bhurry\b/i, label: "hurry" },
  { re: /\bcountdown\b/i, label: "countdown" },
  { re: /\blimited spots\b/i, label: "limited spots" },
  { re: /\bexclusive access\b/i, label: "exclusive access" },
  { re: /\bwaitlist\b/i, label: "waitlist" },
  { re: /\bjoin the waitlist\b/i, label: "join the waitlist" },
  { re: /\bstartup\b/i, label: "startup" },
  { re: /\bscale fast\b/i, label: "scale fast" },
  { re: /\bgrowth hack\b/i, label: "growth hack" },
  { re: /\bcreator monetization\b/i, label: "creator monetization" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\blevel up\b/i, label: "level up" },
  { re: /\bunlock features\b/i, label: "unlock features" },
  { re: /\bpremium intelligence\b/i, label: "premium intelligence" },
  { re: /\bupgrade your growth\b/i, label: "upgrade your growth" },
  { re: /\bai insights\b/i, label: "AI insights" },
  { re: /\bdon't miss\b/i, label: "don't miss" },
  { re: /\bnever lose\b/i, label: "never lose" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

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
  return trimmed.includes("validate:pilot") || trimmed.includes("validate-pilot-restraint");
}

function isAllowedStreakContext(line) {
  return /\b(?:no|not a)\s+streak\b/i.test(line);
}

function isAllowedForbiddenContext(line) {
  return /\bFORBIDDEN\b|\bReject\b|\bNEVER\b/i.test(line);
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const isUserFacing =
    (file.includes(`${path.sep}app${path.sep}`) &&
      file.endsWith("page.tsx") &&
      !file.includes(`${path.sep}debug${path.sep}`)) ||
    (file.includes(`${path.sep}components${path.sep}`) &&
      !file.includes(`${path.sep}debug${path.sep}`) &&
      !file.includes(`${path.sep}billing${path.sep}`));

  if (!isUserFacing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;
    if (isAllowedForbiddenContext(line)) return;

    for (const { re, label } of FORBIDDEN_PILOT_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Pilot restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Pilot restraint validation passed.");
