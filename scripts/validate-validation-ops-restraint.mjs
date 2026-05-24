#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "app/launch",
  "lib/research/",
  "lib/debug/validation-ops-review.ts",
  "scripts/",
];

const FORBIDDEN_OPS_PHRASES = [
  { re: /\bgrowth hack\b/i, label: "growth hack" },
  { re: /\bengagement score\b/i, label: "engagement score" },
  { re: /\bconversion funnel\b/i, label: "conversion funnel" },
  { re: /\bdaily active\b/i, label: "daily active" },
  { re: /\bpower user\b/i, label: "power user" },
  { re: /\bgamif/i, label: "gamification" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\blevel up\b/i, label: "level up" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bupgrade now\b/i, label: "upgrade now" },
  { re: /\bsubscribe now\b/i, label: "subscribe now" },
  { re: /\blimited time\b/i, label: "limited time" },
  { re: /\bdashboard\b/i, label: "dashboard" },
  { re: /\bachievement\b/i, label: "achievement" },
  { re: /\boptimize engagement\b/i, label: "optimize engagement" },
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
    trimmed.includes("validate:validation-ops") ||
    trimmed.includes("validate-validation-ops-restraint")
  );
}

function isAllowedStreakContext(line) {
  return /\b(?:no|not a)\s+streak\b/i.test(line);
}

function isAllowedDashboardContext(line) {
  return /\b(?:not a|no)\s+(?:growth\s+)?dashboard\b/i.test(line);
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const isUserFacing =
    (file.includes(`${path.sep}app${path.sep}`) &&
      file.endsWith("page.tsx") &&
      !file.includes(`${path.sep}debug${path.sep}`)) ||
    (file.includes(`${path.sep}components${path.sep}`) &&
      !file.includes(`${path.sep}debug${path.sep}`));

  if (!isUserFacing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of FORBIDDEN_OPS_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        if (label === "dashboard" && isAllowedDashboardContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Validation ops restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Validation ops restraint validation passed.");
