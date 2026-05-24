#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/personalization/visual-tone.ts",
  "lib/personalization/ambient-adaptation.ts",
  "lib/personalization/photo-preferences.ts",
  "lib/personalization/soft-emotional-timeline.ts",
  "lib/photo-storage.ts",
  "lib/photo/compress.ts",
  "lib/photo/integrity.ts",
  "components/settings/PersonalizationSettings.tsx",
  "components/entry/EntryPhotoAttachment.tsx",
  "app/feelings-timeline/page.tsx",
];

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "lib/personalization/",
  "lib/photo-storage.ts",
  "lib/photo/",
  "components/settings/PersonalizationSettings.tsx",
  "components/entry/EntryPhotoAttachment.tsx",
  "app/feelings-timeline/",
  "scripts/",
];

const FORBIDDEN_PERSONALIZATION_PHRASES = [
  { re: /\bmood dashboard\b/i, label: "mood dashboard" },
  { re: /\bproductivity chart\b/i, label: "productivity chart" },
  { re: /\bemotion tracking\b/i, label: "emotion tracking" },
  { re: /\bgamified emotion\b/i, label: "gamified emotion" },
  { re: /\bsticker\b/i, label: "sticker" },
  { re: /\bcute diary\b/i, label: "cute diary" },
  { re: /\bchildish customization\b/i, label: "childish customization" },
  { re: /\bai[- ]generated memory art\b/i, label: "AI-generated memory art" },
  { re: /\bgenerate.*image\b/i, label: "generate image" },
  { re: /\bphoto feed\b/i, label: "photo feed" },
  { re: /\binstagram\b/i, label: "instagram" },
  { re: /\bphoto filters?\b/i, label: "photo filters" },
  { re: /\bimage filters?\b/i, label: "image filters" },
  { re: /\bemoji theme\b/i, label: "emoji theme" },
  { re: /\bbright theme\b/i, label: "bright theme" },
  { re: /\bhabit tracker\b/i, label: "habit tracker" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Personalization restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const feelingsPage = fs.readFileSync(
  path.join(ROOT, "app/feelings-timeline/page.tsx"),
  "utf8",
);
if (!feelingsPage.includes("How this has felt over time")) {
  console.error("Personalization validation failed — missing soft timeline copy.");
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

function isAllowedFilterContext(line) {
  return /\bno filters\b/i.test(line) || /FORBIDDEN.*filter/i.test(line);
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

    for (const { re, label } of FORBIDDEN_PERSONALIZATION_PHRASES) {
      if (re.test(line)) {
        if (label === "photo filters" && isAllowedFilterContext(line)) continue;
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Personalization restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Personalization restraint validation passed.");
