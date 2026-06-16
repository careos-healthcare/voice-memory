#!/usr/bin/env node
/**
 * Archive Reduction Layer v3
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
  "lib/archive/archive-state-object.ts",
  "types/archive-state-object.ts",
  "lib/archive/archive-reduction-v3-copy.ts",
  "lib/archive/archive-health-v3.ts",
  "lib/archive/archive-watch-v3.ts",
  "components/archive/ArchiveReductionV3Home.tsx",
  "components/archive/ArchiveWatchCard.tsx",
  "components/archive/ArchiveHealthLine.tsx",
  "components/archive/DiscoverWhatChanged.tsx",
]) {
  mustExist(rel);
}

const stateObj = read("lib/archive/archive-state-object.ts");
for (const fn of [
  "buildArchiveStateObject",
  "evidenceSummary",
  "changeSummary",
  "watchItem",
]) {
  if (!stateObj.includes(fn)) fail(`archive-state-object missing ${fn}`);
}

const v3Home = read("components/archive/EvidenceArchiveHome.tsx");
if (
  !v3Home.includes("ProgressiveArchiveHome") &&
  !v3Home.includes("ArchiveReductionV3Home")
) {
  fail("EvidenceArchiveHome must use ProgressiveArchiveHome or ArchiveReductionV3Home");
}
for (const demoted of [
  "ArchiveCommandCenter",
  "ArchiveReputationCard",
  "ArchiveWorthStatement",
  "ArchiveOwnershipPanel",
  "ArchiveMaturityMeter",
  "ArchiveAccuracyTracker",
  "BeliefSurvivalCard",
  "ArchiveHealthSummary",
]) {
  if (v3Home.includes(demoted)) {
    fail(`EvidenceArchiveHome must not surface ${demoted} on main archive`);
  }
}

const v3Copy = read("lib/archive/archive-reduction-v3-copy.ts");
for (const label of [
  "Current Belief",
  "Why The Archive Believes This",
  "What Changed",
  "What To Watch",
  "Advanced Archive Detail",
]) {
  if (!v3Copy.includes(label)) fail(`archive-reduction-v3-copy missing label: ${label}`);
}

const reductionHome = read("components/archive/ArchiveReductionV3Home.tsx");
if (!reductionHome.includes("archive-reduction-v3-copy")) {
  fail("ArchiveReductionV3Home must import v3 copy constants");
}
for (const forbidden of [
  "maturity",
  "ownership",
  "reputation",
  "survival",
  "accuracy",
]) {
  if (new RegExp(`\\b${forbidden}\\b`, "i").test(reductionHome)) {
    fail(`ArchiveReductionV3Home must not reference ${forbidden} in UI copy`);
  }
}

const discover = read("app/discover/page.tsx");
if (!discover.includes("DiscoverWhatChanged")) {
  fail("discover page must use DiscoverWhatChanged");
}
if (discover.includes("ArchiveBeliefHeader") || discover.includes("ArchiveReputationCard")) {
  fail("discover page must not duplicate archive trust/reputation headers");
}

const hub = read("components/archive/ArchiveDetailHub.tsx");
if (
  !hub.includes("ARCHIVE_V3_ADVANCED_DETAIL") &&
  !hub.includes("ARCHIVE_ADVANCED_DETAIL_EYEBROW")
) {
  fail("ArchiveDetailHub must use advanced archive detail copy");
}

const mobile = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
for (const label of [
  "Current Belief",
  "Why The Archive Believes This",
  "What Changed",
  "What To Watch",
  "Evidence",
]) {
  if (!mobile.includes(label)) fail(`mobile archive_belief_screen missing: ${label}`);
}
if (mobile.includes("ArchiveReputationCardMobile")) {
  fail("mobile archive home must not show ArchiveReputationCardMobile above fold");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:archive-reduction-v3"]) {
  fail("package.json missing validate:archive-reduction-v3");
}

if (failures.length) {
  console.error("validate-archive-reduction-v3 failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-reduction-v3 ok");
