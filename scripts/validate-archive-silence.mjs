#!/usr/bin/env node
/**
 * Archive Silence Detection — meaningful absence from timeline + existing signals.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "types/archive-silence.ts",
  "lib/archive/archive-silence.ts",
  "components/archive/ArchiveSilenceCard.tsx",
];

for (const rel of required) mustExist(rel);

const lib = read("lib/archive/archive-silence.ts");
for (const phrase of [
  "ARCHIVE_SILENCE_TITLE",
  "buildArchiveSilenceView",
  "readBeliefTimelineHistory",
  "buildPhraseMemory",
  "belief_evidence_gap",
  "life_area_absent",
  "pattern_fading",
  "The archive has not seen evidence for this belief",
  "The archive has not seen evidence from",
  "This pattern may be fading.",
  "assertNoCertaintyLanguage",
  "RESURFACING_MIN_ABSENCE_DAYS",
]) {
  if (!lib.includes(phrase)) fail(`archive-silence missing: ${phrase}`);
}

const forbidden = [
  /\bcertainly\b/i,
  /\bdefinitely\b/i,
  /\bproven\b/i,
  /\bguaranteed\b/i,
  /\bwithout doubt\b/i,
];
for (const pattern of forbidden) {
  if (pattern.test(lib)) fail(`archive-silence contains forbidden certainty language`);
}

const card = read("components/archive/ArchiveSilenceCard.tsx");
if (!card.includes('data-testid="archive-silence-card"')) {
  fail("ArchiveSilenceCard missing test id");
}
if (!card.includes("buildArchiveSilenceView")) {
  fail("ArchiveSilenceCard must call buildArchiveSilenceView");
}

const surfaces = [
  ["components/archive/ArchiveCommandCenter.tsx", "Archive"],
  ["components/archive/BeliefDossier.tsx", "Belief Dossier"],
  ["app/discover/page.tsx", "Discover"],
];

for (const [file, label] of surfaces) {
  const src = read(file);
  if (!src.includes("ArchiveSilenceCard")) {
    fail(`${label} (${file}) must render ArchiveSilenceCard`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-silence"]) {
  fail("package.json missing validate:archive-silence");
}

if (failures.length) {
  console.error("validate-archive-silence failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-silence ok");
