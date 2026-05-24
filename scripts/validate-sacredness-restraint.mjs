#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/restraint/sacredness.ts",
  "lib/restraint/earned-resurfacing.ts",
  "lib/restraint/silence-first.ts",
  "lib/restraint/non-intervention.ts",
  "lib/restraint/restraint-escalation.ts",
  "lib/refinement/rarity-preservation.ts",
  "lib/debug/sacredness-review.ts",
  "app/debug/sacredness-review/page.tsx",
];

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/restraint/",
  "lib/refinement/rarity-preservation.ts",
  "lib/debug/sacredness-review.ts",
  "lib/research/founder-warnings.ts",
  "lib/refinement/anti-template.ts",
  "scripts/",
];

const FORBIDDEN_SACREDNESS_PHRASES = [
  { re: /\bemotional oversupply\b/i, label: "emotional oversupply" },
  { re: /\bfake profundity\b/i, label: "fake profundity" },
  { re: /\bprofound insight\b/i, label: "profound insight" },
  { re: /\blife-changing\b/i, label: "life-changing" },
  { re: /\boptimize engagement\b/i, label: "optimize engagement" },
  { re: /\bdon't miss this\b/i, label: "don't miss this" },
  { re: /\bact now\b/i, label: "act now" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bgrowth hack\b/i, label: "growth hack" },
  { re: /\bunlock insights\b/i, label: "unlock insights" },
  { re: /\bdaily habit\b/i, label: "daily habit" },
  { re: /\bmeaningful moment streak\b/i, label: "meaningful moment streak" },
  { re: /\byour breakthrough\b/i, label: "your breakthrough" },
  { re: /\bhealing journey\b/i, label: "healing journey" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Sacredness restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const sacredness = fs.readFileSync(path.join(ROOT, "lib/restraint/sacredness.ts"), "utf8");
const requiredWarnings = [
  "The archive may be becoming emotionally crowded.",
  "Too many moments are being treated as meaningful.",
  "Silence may now be more valuable than resurfacing.",
];
for (const line of requiredWarnings) {
  if (!sacredness.includes(line)) {
    console.error(`Sacredness validation failed — missing founder warning: "${line}"`);
    process.exit(1);
  }
}

const nonIntervention = fs.readFileSync(path.join(ROOT, "lib/restraint/non-intervention.ts"), "utf8");
if (!nonIntervention.includes("Nothing should surface right now")) {
  console.error("Sacredness validation failed — missing non-intervention conclusion.");
  process.exit(1);
}

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
      !file.includes(`${path.sep}debug${path.sep}`));

  if (!isUserFacing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (isCommentLine(trimmed)) return;

    for (const { re, label } of FORBIDDEN_SACREDNESS_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Sacredness restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Sacredness restraint validation passed.");
