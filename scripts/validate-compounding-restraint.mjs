#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/memory/memory-compounding.ts",
  "lib/memory/slow-realizations.ts",
  "components/ui/badge.tsx",
  "scripts/",
];

const FORBIDDEN_COMPOUNDING_PHRASES = [
  { re: /\btransformed\b/i, label: "transformed" },
  { re: /\bhealing journey\b/i, label: "healing journey" },
  { re: /\bself-improvement\b/i, label: "self-improvement" },
  { re: /\bgrowth journey\b/i, label: "growth journey" },
  { re: /\bbest self\b/i, label: "best self" },
  { re: /\bbreakthrough\b/i, label: "breakthrough" },
  { re: /\bachievement\b/i, label: "achievement" },
  { re: /\bbadge earned\b/i, label: "badge earned" },
  { re: /\bearned badge\b/i, label: "earned badge" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\blevel up\b/i, label: "level up" },
  { re: /\bprogress score\b/i, label: "progress score" },
  { re: /\barchive depth score\b/i, label: "archive depth score" },
  { re: /\bdaily habit\b/i, label: "daily habit" },
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
    trimmed.includes("validate:compounding") ||
    trimmed.includes("validate-compounding-restraint")
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
    if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;
    if (/<Badge\b|from "@\/components\/ui\/badge"/.test(line)) return;

    for (const { re, label } of FORBIDDEN_COMPOUNDING_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && isAllowedStreakContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Compounding restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Compounding restraint validation passed.");
