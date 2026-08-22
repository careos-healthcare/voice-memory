#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "packages/shared/lib/monetization/",
  "packages/shared/lib/subscription.ts",
  "apps/web/components/billing/",
  "apps/web/app/pricing/",
  "scripts/",
];

const FORBIDDEN_MONETIZATION_PHRASES = [
  { re: /\bnever lose your memories\b/i, label: "never lose your memories" },
  { re: /\bdon't lose your memories\b/i, label: "don't lose your memories" },
  { re: /\bunlock your potential\b/i, label: "unlock your potential" },
  { re: /\bupgrade now\b/i, label: "upgrade now" },
  { re: /\bsubscribe now\b/i, label: "subscribe now" },
  { re: /\blimited time\b/i, label: "limited time" },
  { re: /\blast chance\b/i, label: "last chance" },
  { re: /\bact now\b/i, label: "act now" },
  { re: /\bhurry\b/i, label: "hurry" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bgamif/i, label: "gamification" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\blevel up\b/i, label: "level up" },
  { re: /\boptimize your\b/i, label: "optimize your" },
  { re: /\bmore insights\b/i, label: "more insights" },
  { re: /\bmore intelligence\b/i, label: "more intelligence" },
  { re: /\bfear of missing\b/i, label: "fear of missing" },
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
  return (
    trimmed.includes("validate:monetization") ||
    trimmed.includes("validate-monetization-restraint")
  );
}

function isAllowedStreakContext(line) {
  return /\b(?:no|not a)\s+streak\b/i.test(line);
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

    for (const { re, label } of FORBIDDEN_MONETIZATION_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Monetization restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Monetization restraint validation passed.");
