#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "lib/marketing"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/marketing/acquisition-copy.ts",
  "lib/marketing/acquisition-restraint.ts",
  "scripts/",
];

const FORBIDDEN_ACQUISITION_PHRASES = [
  { re: /\blongitudinal\b/i, label: "longitudinal" },
  { re: /\bcontinuity intelligence\b/i, label: "continuity intelligence" },
  { re: /\barchive graph\b/i, label: "archive graph" },
  { re: /\bemotional AI\b/i, label: "emotional AI" },
  { re: /\bidentity engine\b/i, label: "identity engine" },
  { re: /\bmemory system\b/i, label: "memory system" },
  { re: /\breflection engine\b/i, label: "reflection engine" },
  { re: /\bcognitive\b/i, label: "cognitive" },
  { re: /\bbehavioral intelligence\b/i, label: "behavioral intelligence" },
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
    trimmed.includes("validate:acquisition") ||
    trimmed.includes("validate-acquisition-restraint")
  );
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const isUserPage =
    file.includes(`${path.sep}app${path.sep}`) &&
    file.endsWith("page.tsx") &&
    !file.includes(`${path.sep}debug${path.sep}`);

  const isMarketing = file.includes(`${path.sep}lib${path.sep}marketing${path.sep}`);

  if (!isUserPage && !isMarketing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (!trimmed || isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of FORBIDDEN_ACQUISITION_PHRASES) {
      if (re.test(line)) {
        violations.push({
          file: path.relative(ROOT, file),
          lineNo: index + 1,
          label,
          line: trimmed.slice(0, 120),
        });
      }
    }
  });
}

if (violations.length > 0) {
  console.error(`validate:acquisition failed — ${violations.length} issue(s):\n`);
  for (const v of violations.slice(0, 40)) {
    console.error(`  ${v.file}:${v.lineNo}  [${v.label}]  ${v.line}`);
  }
  if (violations.length > 40) {
    console.error(`  … and ${violations.length - 40} more`);
  }
  process.exit(1);
}

console.log(`validate:acquisition passed (${files.length} files scanned)`);
