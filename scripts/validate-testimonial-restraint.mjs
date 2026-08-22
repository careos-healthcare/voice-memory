#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "packages/shared/lib/social-proof/testimonial-review.ts",
  "packages/shared/lib/social-proof/emotional-proof.ts",
  "scripts/",
];

const FORBIDDEN_TESTIMONIAL_PHRASES = [
  { re: /\blife-changing\b/i, label: "life-changing" },
  { re: /\btransformed me\b/i, label: "transformed me" },
  { re: /\bchanged everything\b/i, label: "changed everything" },
  { re: /\bproductivity boost\b/i, label: "productivity boost" },
  { re: /\bbest version of myself\b/i, label: "best version of myself" },
  { re: /\bhealing system\b/i, label: "healing system" },
  { re: /\bbreakthrough ai\b/i, label: "breakthrough AI" },
  { re: /\boptimized my life\b/i, label: "optimized my life" },
  { re: /\bnever miss a reflection\b/i, label: "never miss a reflection" },
  { re: /\busers like you\b/i, label: "users like you" },
  { re: /\bjoin thousands\b/i, label: "join thousands" },
  { re: /\bgame changer\b/i, label: "game changer" },
  { re: /\bstreak\b/i, label: "streak" },
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
    trimmed.includes("validate:testimonial") ||
    trimmed.includes("validate-testimonial-restraint")
  );
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const isUserFacing =
    (file.includes(`${path.sep}app${path.sep}`) && file.endsWith("page.tsx")) ||
    file.includes(`${path.sep}components${path.sep}`);

  if (!isUserFacing) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

    for (const { re, label } of FORBIDDEN_TESTIMONIAL_PHRASES) {
      if (re.test(line)) {
        if (label === "streak" && /\b(?:no|not a)\s+streak\b/i.test(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Testimonial restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Testimonial restraint validation passed.");
