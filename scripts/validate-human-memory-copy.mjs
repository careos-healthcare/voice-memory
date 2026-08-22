#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components"];
const SKIP = [`${path.sep}debug${path.sep}`, `${path.sep}api${path.sep}`];
const EXT = new Set([".tsx", ".ts"]);

const memoryLang = fs.readFileSync(path.join(ROOT, "packages/shared/lib/memory-language.ts"), "utf8");
if (!memoryLang.includes("MEMORY_LANGUAGE") || !memoryLang.includes("BANNED_USER_MEMORY_PHRASES")) {
  console.error("human-memory-copy: missing lib/memory-language.ts exports");
  process.exit(1);
}

const banned = [
  /\bai journal\b/i,
  /\bai-powered\b/i,
  /\binsight engine\b/i,
  /\bpattern analysis\b/i,
  /\bemotional data\b/i,
  /\banalytics dashboard\b/i,
  /\bmetrics dashboard\b/i,
  /\bmemory intelligence\b/i,
  /\bintelligence layer\b/i,
  /\bwe detected\b/i,
  /\bour system recommends\b/i,
  /\bthe system recommends\b/i,
  /\byour score\b/i,
  /\bperformance score\b/i,
];

function shouldSkip(filePath) {
  const rel = path.relative(ROOT, filePath);
  return SKIP.some((part) => rel.includes(part.replace(/\//g, path.sep)));
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

function isStringLine(trimmed) {
  if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("import ")) {
    return false;
  }
  return /["'`][^"'`]{8,}["'`]/.test(trimmed);
}

const failures = [];
for (const dir of SCAN_DIRS) {
  for (const file of walk(path.join(ROOT, dir))) {
    const lines = fs.readFileSync(file, "utf8").split("\n");
    lines.forEach((line, index) => {
      const trimmed = line.trim();
      if (!isStringLine(trimmed)) return;
      for (const re of banned) {
        if (re.test(line)) {
          failures.push(`${path.relative(ROOT, file)}:${index + 1}  ${re}`);
        }
      }
    });
  }
}

for (const token of ["You said this before", "This came back", "Your own words came back"]) {
  if (!memoryLang.includes(token)) {
    failures.push(`lib/memory-language.ts missing ${token}`);
  }
}
if (!fs.readFileSync(path.join(ROOT, "packages/shared/lib/product-copy.ts"), "utf8").includes("MEMORY_LANGUAGE")) {
  failures.push("packages/shared/lib/product-copy.ts must use MEMORY_LANGUAGE");
}

if (failures.length > 0) {
  console.error("Human memory copy validation failed:\n");
  for (const f of failures.slice(0, 30)) console.error(`  ${f}`);
  process.exit(1);
}

console.log("Human memory copy validation passed.");
