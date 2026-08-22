#!/usr/bin/env node
/**
 * Emotional Elegance Layer v1 — human archive phrasing, no analytical cold copy.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "packages/shared/lib/archive/archive-emotional-copy.ts",
  "packages/shared/lib/archive/archive-meaning-summary.ts",
  "apps/web/components/archive/ArchiveMeaningSummary.tsx",
];

for (const rel of required) mustExist(rel);

const emotional = read("packages/shared/lib/archive/archive-emotional-copy.ts");
for (const phrase of [
  "The archive has become more certain.",
  "New experiences supported this view.",
  "Recent reflections challenged this belief.",
  "The archive no longer sees enough evidence.",
  "toArchiveEmotionalCopy",
]) {
  if (!emotional.includes(phrase)) fail(`archive-emotional-copy missing: ${phrase}`);
}

const commandCenter = read("apps/web/components/archive/ArchiveCommandCenter.tsx");
if (!commandCenter.includes("toArchiveEmotionalCopy")) {
  fail("ArchiveCommandCenter must humanize change lines");
}
const archiveHome = read("apps/web/components/archive/EvidenceArchiveHome.tsx");
if (!archiveHome.includes("ArchiveMeaningSummary")) {
  fail("ArchiveMeaningSummary must live below fold on archive home (not command center)");
}

const meaning = read("packages/shared/lib/archive/archive-meaning-summary.ts");
for (const phrase of [
  "ARCHIVE_EMOTIONAL.notCertainYet",
  "ARCHIVE_EMOTIONAL.stillChanging",
  "For now, your archive",
  "buildArchiveMeaningSummary",
]) {
  if (!meaning.includes(phrase)) fail(`archive-meaning-summary missing: ${phrase}`);
}

const movementCopy = read("packages/shared/lib/archive/archive-movement-copy.ts");
if (movementCopy.includes('"Confidence increased"')) {
  fail("archive-movement-copy must not use analytical Confidence increased");
}
if (!movementCopy.includes("ARCHIVE_EMOTIONAL")) {
  fail("archive-movement-copy must import ARCHIVE_EMOTIONAL");
}

const userFacing = [
  "packages/shared/lib/archive/archive-movement-copy.ts",
  "packages/shared/lib/archive/archive-belief.ts",
  "apps/web/components/archive/ArchiveCommandCenter.tsx",
  "packages/shared/lib/discover/theory-movement-copy.ts",
  "apps/web/app/discover/page.tsx",
];

const forbidden = [
  /"Confidence increased"/,
  /"Evidence added"/,
  /"Theory weakened"/,
  /"Theory retired"/,
];

for (const file of userFacing) {
  const src = read(file);
  for (const pattern of forbidden) {
    if (pattern.test(src)) fail(`${file} contains forbidden analytical phrase`);
  }
}

const pkg = JSON.parse(read("package.json"));
}

if (failures.length) {
  console.error("validate-archive-emotional-elegance failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-emotional-elegance ok");
