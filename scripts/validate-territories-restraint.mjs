#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/territories/emotional-territories.ts",
  "lib/territories/territory-preferences.ts",
  "lib/territories/territory-observation.ts",
  "types/emotional-territory.ts",
  "components/territories/TerritorySections.tsx",
  "components/territories/TerritoryRenameControl.tsx",
  "app/territories/page.tsx",
  "app/territories/[slug]/page.tsx",
];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/territories/",
  "components/territories/",
  "app/territories/",
  "scripts/",
];

const FORBIDDEN_PHRASES = [
  { re: /\bmood dashboard\b/i, label: "mood dashboard" },
  { re: /\bmood taxonomy\b/i, label: "mood taxonomy" },
  { re: /\bclinical categor/i, label: "clinical categories" },
  { re: /\bproductivity dashboard\b/i, label: "productivity dashboard" },
  { re: /\bproductivity chart\b/i, label: "productivity chart" },
  { re: /\bemotion tracking\b/i, label: "emotion tracking" },
  { re: /\bhabit tracker\b/i, label: "habit tracker" },
  { re: /\bscoreboard\b/i, label: "scoreboard" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
const SCAN_DIRS = ["app", "components", "lib"];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Territories restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const territoriesPage = fs.readFileSync(path.join(ROOT, "app/territories/page.tsx"), "utf8");
if (!territoriesPage.includes("Emotional territories")) {
  console.error("Territories validation failed — missing page title.");
  process.exit(1);
}

const coreLib = fs.readFileSync(
  path.join(ROOT, "lib/territories/emotional-territories.ts"),
  "utf8",
);
for (const label of ["Around work", "Around home", "About money"]) {
  if (!coreLib.includes(label)) {
    console.error(`Territories validation failed — missing copy example "${label}".`);
    process.exit(1);
  }
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

function isAllowedContext(line, label) {
  if (label === "diagnosis") {
    return /\bnot (?:therapy or )?diagnosis\b/i.test(line) || /\bno diagnosis\b/i.test(line);
  }
  return false;
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

    for (const { re, label } of FORBIDDEN_PHRASES) {
      if (re.test(line)) {
        if (isAllowedContext(line, label)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Territories restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Territories restraint validation passed.");
