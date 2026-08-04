#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/atmosphere/memory-atmosphere.ts",
  "lib/atmosphere/atmosphere-anchors.ts",
  "lib/atmosphere/atmosphere-storage.ts",
  "lib/atmosphere/atmosphere-observation.ts",
  "types/atmosphere.ts",
  "components/entry/EntryAtmosphereAttachment.tsx",
  "experiments/backend/app/api/atmosphere/route.ts",
];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  "lib/atmosphere/",
  "components/entry/EntryAtmosphereAttachment.tsx",
  "experiments/backend/app/api/atmosphere/",
  "scripts/",
];

const FORBIDDEN_PHRASES = [
  { re: /\bai interpreted your soul\b/i, label: "AI interpreted your soul" },
  { re: /\bfantasy art\b/i, label: "fantasy art" },
  { re: /\bcinematic trauma\b/i, label: "cinematic trauma" },
  { re: /\btherapy symbolism\b/i, label: "therapy symbolism" },
  { re: /\bautomatic generation\b/i, label: "automatic generation" },
  { re: /\banimated background\b/i, label: "animated background" },
  { re: /\bgenerate.*image\b/i, label: "generate image" },
  { re: /\bai[- ]generated memory art\b/i, label: "AI-generated memory art" },
  { re: /\bphoto feed\b/i, label: "photo feed" },
  { re: /\bbright theme\b/i, label: "bright theme" },
];

const WALLPAPER_LABELS = [
  "Foggy street",
  "Morning glow",
  "Quiet room",
  "Soft light",
  "Rainy window",
  "Dusk field",
  "Abstract color field",
  "Create quiet atmosphere",
  "A quiet visual, not a memory",
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
const SCAN_DIRS = ["app", "components", "lib"];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Atmosphere restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const typesAtmosphere = fs.readFileSync(path.join(ROOT, "types/atmosphere.ts"), "utf8");
if (!typesAtmosphere.includes("AtmosphereFingerprint")) {
  console.error("Atmosphere validation failed — types/atmosphere.ts must define AtmosphereFingerprint.");
  process.exit(1);
}

const memoryAtmosphere = fs.readFileSync(
  path.join(ROOT, "lib/atmosphere/memory-atmosphere.ts"),
  "utf8",
);
if (!memoryAtmosphere.includes("fingerprint")) {
  console.error("Atmosphere validation failed — buildAtmosphereMeta must attach fingerprint.");
  process.exit(1);
}

const anchors = fs.readFileSync(
  path.join(ROOT, "lib/atmosphere/atmosphere-anchors.ts"),
  "utf8",
);
for (const token of ["EMOTIONAL_ATMOSPHERE_CATALOG", "buildAtmosphereFingerprint", "pickEmotionalContextLine"]) {
  if (!anchors.includes(token)) {
    console.error(`Atmosphere validation failed — atmosphere-anchors.ts must export ${token}.`);
    process.exit(1);
  }
}

const component = fs.readFileSync(
  path.join(ROOT, "components/entry/EntryAtmosphereAttachment.tsx"),
  "utf8",
);
const componentMarkers = [
  ["A visual echo", "ATMOSPHERE_SECTION_TITLE"],
  ["Add a visual echo", "ATMOSPHERE_EXPAND_LABEL"],
  ["Generate another", "ATMOSPHERE_GENERATE_ANOTHER"],
  ["Generated images may not match what happened.", "ATMOSPHERE_SECTION_DISCLAIMER"],
  "buildAtmospherePickerPresentation",
  "AtmosphereChoiceCard",
];
for (const marker of componentMarkers) {
  const options = Array.isArray(marker) ? marker : [marker];
  if (!options.some((token) => component.includes(token))) {
    console.error(
      `Atmosphere validation failed — missing ${options.join(" or ")} in EntryAtmosphereAttachment.`,
    );
    process.exit(1);
  }
}

if (!anchors.includes("A visual echo")) {
  console.error('Atmosphere validation failed — atmosphere-anchors must define "A visual echo" title.');
  process.exit(1);
}

for (const banned of WALLPAPER_LABELS) {
  if (component.includes(banned)) {
    console.error(
      `Atmosphere validation failed — wallpaper-picker label "${banned}" in EntryAtmosphereAttachment.`,
    );
    process.exit(1);
  }
}

if (component.includes("ATMOSPHERE_STYLE_OPTIONS")) {
  console.error(
    "Atmosphere validation failed — equal-weight style grid must not appear in EntryAtmosphereAttachment.",
  );
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

function isAllowedContext(line, label) {
  if (label === "fantasy art" || label === "automatic generation" || label === "generate image") {
    return /\bno fantasy\b/i.test(line) || /\bnever automatic\b/i.test(line) || /\bnot a memory\b/i.test(line);
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
  console.error("Atmosphere restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Atmosphere restraint validation passed.");
