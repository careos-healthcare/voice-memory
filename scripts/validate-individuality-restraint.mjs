#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/identity/archive-individuality.ts",
  "lib/identity/personalized-restraint.ts",
  "lib/identity/voice-texture.ts",
  "lib/identity/longitudinal-individuality.ts",
  "lib/refinement/anti-template.ts",
  "lib/debug/archive-individuality-review.ts",
  "lib/debug/archive-divergence-review.ts",
  "app/debug/archive-individuality/page.tsx",
  "app/debug/archive-divergence/page.tsx",
];

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/identity/",
  "lib/refinement/anti-template.ts",
  "lib/debug/archive-individuality-review.ts",
  "lib/debug/archive-divergence-review.ts",
  "lib/research/founder-warnings.ts",
  "lib/memory/language-fingerprint.ts",
  "scripts/",
];

const FORBIDDEN_INDIVIDUALITY_PHRASES = [
  { re: /\bpsychographic\b/i, label: "psychographic" },
  { re: /\bpersonality type\b/i, label: "personality type" },
  { re: /\bmbti\b/i, label: "MBTI" },
  { re: /\benneagram\b/i, label: "enneagram" },
  { re: /\bintrovert\b/i, label: "introvert typing" },
  { re: /\bextrovert\b/i, label: "extrovert typing" },
  { re: /\boptimize your\b/i, label: "optimize your" },
  { re: /\bpersonalized for you\b/i, label: "personalized for you" },
  { re: /\btailored experience\b/i, label: "tailored experience" },
  { re: /\buser segment\b/i, label: "user segment" },
  { re: /\bcohort profile\b/i, label: "cohort profile" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bgrowth hack\b/i, label: "growth hack" },
  { re: /\bmanipulative personalization\b/i, label: "manipulative personalization" },
  { re: /\byour archetype\b/i, label: "your archetype" },
  { re: /\bemotional type\b/i, label: "emotional type" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Individuality restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const antiTemplate = fs.readFileSync(path.join(ROOT, "lib/refinement/anti-template.ts"), "utf8");
if (!antiTemplate.includes("This callback may sound generated.")) {
  console.error("Individuality validation failed — missing anti-template warning.");
  process.exit(1);
}

const individualityReview = fs.readFileSync(
  path.join(ROOT, "lib/debug/archive-individuality-review.ts"),
  "utf8",
);
if (!individualityReview.includes("The product may be losing emotional specificity.")) {
  console.error("Individuality validation failed — missing specificity founder warning.");
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

    for (const { re, label } of FORBIDDEN_INDIVIDUALITY_PHRASES) {
      if (re.test(line)) {
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Individuality restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Individuality restraint validation passed.");
