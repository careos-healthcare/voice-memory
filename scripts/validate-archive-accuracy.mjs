#!/usr/bin/env node
/**
 * Archive Accuracy Tracker — belief vs future evidence from existing outcomes.
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
  "packages/shared/types/archive-accuracy.ts",
  "packages/shared/lib/archive/archive-accuracy.ts",
  "apps/web/components/archive/ArchiveAccuracyTracker.tsx",
];

for (const rel of required) mustExist(rel);

const lib = read("packages/shared/lib/archive/archive-accuracy.ts");
for (const phrase of [
  "ARCHIVE_ACCURACY_TITLE",
  "buildArchiveAccuracyView",
  "buildBlindSpotAccelerationReport",
  "readAllInsightOutcomeEvents",
  "readAllExperimentCommitments",
  "readArchiveFollowupAnswers",
  "confirmed",
  "challenged",
  "unclear",
  "Confirmed",
  "Challenged",
  "Unclear",
  "assertNoCertaintyLanguage",
]) {
  if (!lib.includes(phrase)) fail(`archive-accuracy missing: ${phrase}`);
}

const component = read("apps/web/components/archive/ArchiveAccuracyTracker.tsx");
if (!component.includes('data-testid="archive-accuracy-tracker"')) {
  fail("ArchiveAccuracyTracker missing test id");
}
if (!component.includes("buildArchiveAccuracyView")) {
  fail("ArchiveAccuracyTracker must call buildArchiveAccuracyView");
}

const surfaces = [
  ["apps/web/components/archive/ArchiveCommandCenter.tsx", "Archive"],
  ["apps/web/components/archive/BeliefDossier.tsx", "Belief Dossier"],
  ["apps/web/app/discover/page.tsx", "Discover"],
];

for (const [file, label] of surfaces) {
  const src = read(file);
  if (!src.includes("ArchiveAccuracyTracker")) {
    fail(`${label} (${file}) must render ArchiveAccuracyTracker`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-accuracy"]) {
  fail("package.json missing validate:archive-accuracy");
}

if (failures.length) {
  console.error("validate-archive-accuracy failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-accuracy ok");
