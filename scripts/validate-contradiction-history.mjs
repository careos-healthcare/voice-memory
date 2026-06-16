#!/usr/bin/env node
/**
 * Contradiction History — belief reversals from existing timeline signals.
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
  "types/contradiction-history.ts",
  "lib/archive/contradiction-history.ts",
  "components/archive/ArchiveContradictionHistory.tsx",
];

for (const rel of required) mustExist(rel);

const lib = read("lib/archive/contradiction-history.ts");
for (const phrase of [
  "CONTRADICTION_HISTORY_HEADLINE",
  "Your archive has changed its mind before.",
  "buildContradictionHistoryView",
  "buildBeliefChangeTimeline",
  "readBeliefTimelineHistory",
  "previousBelief",
  "currentBelief",
  "archiveExplanation",
  "assertNoCertaintyLanguage",
]) {
  if (!lib.includes(phrase)) fail(`contradiction-history missing: ${phrase}`);
}

const component = read("components/archive/ArchiveContradictionHistory.tsx");
for (const phrase of [
  'data-testid="archive-contradiction-history"',
  "buildContradictionHistoryView",
  "Previous belief",
  "Current belief",
  "Supporting evidence",
  "Timeline",
  "Archive explanation",
  "BeliefChangeTimeline",
  "ArchiveBeliefEvidenceSection",
]) {
  if (!component.includes(phrase)) fail(`ArchiveContradictionHistory missing: ${phrase}`);
}

const surfaces = [
  ["components/archive/ArchiveCommandCenter.tsx", "Archive"],
  ["components/archive/BeliefDossier.tsx", "Belief Dossier"],
  ["app/discover/page.tsx", "Discover"],
];

for (const [file, label] of surfaces) {
  const src = read(file);
  if (!src.includes("ArchiveContradictionHistory")) {
    fail(`${label} (${file}) must render ArchiveContradictionHistory`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:contradiction-history"]) {
  fail("package.json missing validate:contradiction-history");
}

if (failures.length) {
  console.error("validate-contradiction-history failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-contradiction-history ok");
