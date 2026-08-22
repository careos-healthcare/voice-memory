#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "packages/shared/lib/sharing/quiet-sharing.ts",
  "scripts/",
];

const FORBIDDEN_SHARING_PHRASES = [
  { re: /\bmotivational\b/i, label: "motivational" },
  { re: /\binspirational\b/i, label: "inspirational" },
  { re: /\bhealing journey\b/i, label: "healing journey" },
  { re: /\bbecome your best self\b/i, label: "become your best self" },
  { re: /\bmain character\b/i, label: "main character" },
  { re: /\bromanticize your life\b/i, label: "romanticize your life" },
  { re: /\bgrowth journey\b/i, label: "growth journey" },
  { re: /\bgo viral\b/i, label: "go viral" },
  { re: /\bshare your growth\b/i, label: "share your growth" },
  { re: /\bpost\b/i, label: "post" },
  { re: /\bhustle\b/i, label: "hustle" },
  { re: /\bmanifest\b/i, label: "manifest" },
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
    trimmed.includes("validate:sharing") ||
    trimmed.includes("validate-sharing-restraint")
  );
}

function isAllowedPostContext(line) {
  return /\b(?:no|never|don't|do not)\s+post\b/i.test(line);
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const isUserFacing =
    (file.includes(`${path.sep}app${path.sep}`) &&
      file.endsWith("page.tsx") &&
      !file.includes(`${path.sep}debug${path.sep}`)) ||
    file.includes(`${path.sep}components${path.sep}sharing${path.sep}`);

  if (!isUserFacing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of FORBIDDEN_SHARING_PHRASES) {
      if (re.test(line)) {
        if (label === "post" && isAllowedPostContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Sharing restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Sharing restraint validation passed.");
