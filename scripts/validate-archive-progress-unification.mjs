#!/usr/bin/env node
/**
 * Unified Archive Progress v1
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

for (const rel of [
  "packages/shared/lib/archive/archive-maturity-engine.ts",
  "packages/shared/lib/archive/archive-progress-copy.ts",
  "packages/shared/types/archive-progress.ts",
  "apps/web/components/archive/ArchiveProgressBar.tsx",
  "scripts/validate-archive-progress-unification.mjs",
]) {
  mustExist(rel);
}

const engine = read("packages/shared/lib/archive/archive-maturity-engine.ts");
for (const token of [
  "ArchiveMaturityEngine",
  "reflectionCount",
  "beliefCount",
  "beliefChanges",
  "reputationScore",
  "timelineAgeDays",
  "buildArchiveProgressView",
]) {
  if (!engine.includes(token)) fail(`archive-maturity-engine missing ${token}`);
}

const progressCopy = read("packages/shared/lib/archive/archive-progress-copy.ts");
if (!progressCopy.includes("Your archive is becoming harder to fool.")) {
  fail("archive-progress-copy must define harder-to-fool headline");
}
const progressBar = read("apps/web/components/archive/ArchiveProgressBar.tsx");
if (!progressBar.includes("view.headline")) {
  fail("ArchiveProgressBar must render progress headline");
}
for (const token of ["Current stage", "Next milestone", "buildArchiveProgressView"]) {
  if (!progressBar.includes(token)) fail(`ArchiveProgressBar missing ${token}`);
}

const archiveHome = read("apps/web/components/archive/EvidenceArchiveHome.tsx");
if (!archiveHome.includes("ArchiveProgressBar")) {
  fail("archive home must render dominant ArchiveProgressBar");
}
if (archiveHome.includes("<ArchiveCaseFileProgress")) {
  fail("archive home must not prominently render ArchiveCaseFileProgress");
}

const recorder = read("apps/web/components/Recorder.tsx");
if (!recorder.includes("ArchiveProgressBar")) {
  fail("Recorder must render ArchiveProgressBar after save");
}
if (recorder.includes("ArchiveValueBanner") || recorder.includes("ArchiveMaturityMeter")) {
  fail("Recorder must not use demoted progress banners");
}
if (!recorder.includes("displayLabel")) {
  fail("Recorder must use reflection receipt displayLabel");
}

const receipt = read("packages/shared/lib/archive/reflection-impact-receipt.ts");
if (!receipt.includes("maturityDelta")) fail("receipt must compute maturityDelta");
if (!receipt.includes("ARCHIVE_MATURITY_INCREASED_LABEL")) {
  fail("receipt must label archive maturity increase");
}
if (!receipt.includes("displayLabel")) fail("receipt must expose displayLabel");

for (const [page, banned] of [
  ["apps/web/app/page.tsx", "ArchiveValueBanner"],
  ["apps/web/app/page.tsx", "ArchiveOwnershipSparseLine"],
  ["apps/web/components/Recorder.tsx", "PatternActivationProgress"],
]) {
  if (read(page).includes(banned)) fail(`${page} must demote ${banned}`);
}

const demotedCopy = read("packages/shared/lib/archive/archive-progress-copy.ts");
if (!demotedCopy.includes("DEMOTED_ARCHIVE_PROGRESS_SURFACES")) {
  fail("archive-progress-copy must list demoted surfaces");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-progress-unification"]) {
  fail("package.json missing validate:archive-progress-unification");
}

if (failures.length) {
  console.error("validate-archive-progress-unification failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-progress-unification passed");
