#!/usr/bin/env node
/**
 * Archive Milestones v1 — archive history, not gamification.
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

const FORBIDDEN = [
  /\bbadge\b/i,
  /\bachievement\b/i,
  /\bunlocked\b/i,
  /\bXP\b/i,
  /\bpoints\b/i,
  /\bstreak\b/i,
  /\bgamification\b/i,
  /\byou earned\b/i,
  /\byou unlocked\b/i,
];

const MILESTONE_UI = [
  "lib/archive/archive-milestones.ts",
  "lib/archive/archive-milestone-copy.ts",
  "components/archive/ArchiveLatestMilestone.tsx",
  "components/archive/ArchiveMilestoneTimeline.tsx",
  "components/archive/ArchiveMilestoneFeed.tsx",
  "components/archive/ArchiveMilestoneReturnMoment.tsx",
];

for (const rel of [
  "types/archive-milestone.ts",
  "lib/archive/archive-milestones.ts",
  "lib/archive/archive-milestone-copy.ts",
  "lib/archive/archive-milestone-storage.ts",
  ...MILESTONE_UI,
  "scripts/validate-archive-milestones.mjs",
]) {
  mustExist(rel);
}

const engine = read("lib/archive/archive-milestones.ts");
if (!engine.includes("buildArchiveMilestones")) fail("missing buildArchiveMilestones");
for (const dep of [
  "buildArchiveBeliefView",
  "buildArchiveReputationView",
  "buildBeliefSurvivalView",
  "buildContradictionHistoryView",
  "buildEvidenceArchiveStats",
  "readBeliefTimelineHistory",
  "buildPhraseMemory",
]) {
  if (!engine.includes(dep)) fail(`engine must use ${dep}`);
}
if (/\bfetch\s*\(/.test(engine) || /\bopenai\b/i.test(engine)) {
  fail("engine must not call LLM APIs");
}

for (const type of [
  "FIRST_REFLECTION",
  "FIRST_BELIEF",
  "FIRST_BELIEF_CHANGE",
  "FIRST_CONTRADICTION",
  "FIRST_CROSS_LIFE_PATTERN",
  "FIRST_STRONG_BELIEF",
  "ARCHIVE_CHANGED_ITS_MIND",
  "TEN_REFLECTIONS",
  "FIFTY_REFLECTIONS",
  "ONE_HUNDRED_REFLECTIONS",
  "THIRTY_DAYS_OF_HISTORY",
  "NINETY_DAYS_OF_HISTORY",
  "FIRST_SURVIVED_CHALLENGE",
  "FIRST_REPUTATION_STRONG",
  "FIRST_RECURRING_PATTERN",
  "FIRST_ARCHIVE_QUESTION_ANSWERED",
]) {
  if (!engine.includes(type)) fail(`engine missing type ${type}`);
}

const copy = read("lib/archive/archive-milestone-copy.ts");
if (!copy.includes("Archive History")) fail("missing Archive History headline");
if (copy.includes("You unlocked")) fail("copy must not use user-unlocked framing");

for (const rel of MILESTONE_UI) {
  const src = read(rel).replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
  for (const pattern of FORBIDDEN) {
    if (pattern.test(src)) fail(`${rel} contains gamification tone (${pattern})`);
  }
}

const progressive = read("components/archive/ProgressiveArchiveHome.tsx");
if (!progressive.includes("ArchiveLatestMilestone")) {
  fail("ProgressiveArchiveHome must include ArchiveLatestMilestone");
}
if (!progressive.includes("ArchiveMilestoneFeed")) {
  fail("ProgressiveArchiveHome must include ArchiveMilestoneFeed");
}
if (!progressive.includes("ArchiveMilestoneTimeline")) {
  fail("L2 must include ArchiveMilestoneTimeline");
}

const home = read("components/archive/EvidenceArchiveHome.tsx");
if (!home.includes("ArchiveMilestoneReturnMoment")) {
  fail("EvidenceArchiveHome must include return moment");
}

const mobile = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
if (!mobile.includes("ArchiveLatestMilestoneMobile")) {
  fail("mobile archive must show latest milestone");
}
if (!mobile.includes("ArchiveMilestoneTimelineMobile")) {
  fail("mobile archive must show milestone timeline");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:archive-milestones"]) {
  fail("package.json missing validate:archive-milestones");
}

if (failures.length) {
  console.error("validate-archive-milestones failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-milestones ok");
