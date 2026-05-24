#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "docs/VOICE_MEMORY_PRINCIPLES.md",
  "lib/integrity/emotional-integrity.ts",
  "lib/integrity/removal-review.ts",
  "lib/integrity/archive-simplicity-review.ts",
  "lib/integrity/durability-review.ts",
  "lib/refinement/callback-deduplication.ts",
  "lib/debug/emotional-integrity-review.ts",
  "app/debug/emotional-integrity/page.tsx",
  "app/debug/archive-simplicity/page.tsx",
  "app/debug/durability-review/page.tsx",
];

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/integrity/",
  "lib/refinement/callback-deduplication.ts",
  "lib/debug/emotional-integrity-review.ts",
  "lib/debug/emotional-legitimacy-review.ts",
  "lib/research/founder-warnings.ts",
  "docs/",
  "scripts/",
];

const FORBIDDEN_INTEGRITY_PHRASES = [
  { re: /\bgrowth hack\b/i, label: "growth hack" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\blevel up\b/i, label: "level up" },
  { re: /\bhealing journey\b/i, label: "healing journey" },
  { re: /\bbest self\b/i, label: "best self" },
  { re: /\bdon't miss\b/i, label: "don't miss" },
  { re: /\bact now\b/i, label: "act now" },
  { re: /\bunlock features\b/i, label: "unlock features" },
  { re: /\bpremium intelligence\b/i, label: "premium intelligence" },
  { re: /\bai insights\b/i, label: "AI insights" },
  { re: /\boptimize engagement\b/i, label: "optimize engagement" },
  { re: /\bconversion funnel\b/i, label: "conversion funnel" },
  { re: /\bwaitlist\b/i, label: "waitlist" },
  { re: /\bexclusive access\b/i, label: "exclusive access" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Integrity layer validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const principles = fs.readFileSync(path.join(ROOT, "docs/VOICE_MEMORY_PRINCIPLES.md"), "utf8");
const requiredPrincipleLines = [
  "silence over filler",
  "continuity over novelty",
  "archive permanence over engagement",
  "no productivity framing",
  "no emotional manipulation",
];
for (const line of requiredPrincipleLines) {
  if (!principles.toLowerCase().includes(line)) {
    console.error(`Integrity layer validation failed — principles doc missing: "${line}"`);
    process.exit(1);
  }
}

const emotionalIntegrity = fs.readFileSync(
  path.join(ROOT, "lib/integrity/emotional-integrity.ts"),
  "utf8",
);
if (!emotionalIntegrity.includes("The product may be explaining too much.")) {
  console.error("Integrity layer validation failed — missing explaining-too-much founder warning.");
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

    for (const { re, label } of FORBIDDEN_INTEGRITY_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Integrity restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Integrity restraint validation passed.");
