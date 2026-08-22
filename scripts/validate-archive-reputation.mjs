#!/usr/bin/env node
/**
 * Archive Reputation System v1 — earned belief framing from existing archive signals.
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
  "packages/shared/types/archive-reputation.ts",
  "packages/shared/lib/archive/archive-reputation.ts",
  "packages/shared/lib/archive/archive-reputation-copy.ts",
  "packages/shared/lib/archive/archive-reputation-trust.ts",
  "packages/shared/lib/archive/archive-reputation-movement.ts",
  "apps/web/components/archive/ArchiveReputationCard.tsx",
  "apps/web/components/archive/WhyTheArchiveTrustsThis.tsx",
  "apps/web/components/archive/ArchiveReputationMovement.tsx",
  "packages/shared/lib/internal/archive-reputation-report.ts",
  "apps/mobile/lib/features/archive_reputation/archive_reputation.dart",
  "apps/mobile/lib/widgets/archive_reputation_card_mobile.dart",
];

for (const rel of required) mustExist(rel);

const types = read("packages/shared/types/archive-reputation.ts");
for (const phrase of [
  "ArchiveReputationLevel",
  "very_high",
  "supportingReflections",
  "accuracySignals",
]) {
  if (!types.includes(phrase)) fail(`archive-reputation types missing: ${phrase}`);
}

const engine = read("packages/shared/lib/archive/archive-reputation.ts");
for (const phrase of [
  "buildArchiveReputationView",
  "buildBeliefSurvivalView",
  "buildArchiveAccuracyView",
  "buildContradictionHistoryView",
  "buildEvidenceLocker",
  "readBeliefTimelineHistory",
  "assessArchiveAttachment",
  "buildDivergedPredictionEntryIds",
]) {
  if (!engine.includes(phrase)) fail(`archive-reputation engine missing: ${phrase}`);
}

const forbiddenImports = [
  "openai",
  "pattern-engine",
  "SemanticSearch",
  "generateTheory",
  "llm",
];
for (const token of forbiddenImports) {
  if (engine.includes(token)) fail(`archive-reputation must not import new intelligence: ${token}`);
}

const copy = read("packages/shared/lib/archive/archive-reputation-copy.ts");
for (const phrase of [
  "The archive is still learning.",
  "The archive has started to gather evidence.",
  "This belief appears repeatedly enough",
  "This belief has remained consistent",
  "This belief has earned substantial support",
  "depends on the evidence available",
  "earned the right to believe",
]) {
  if (!copy.includes(phrase)) fail(`archive-reputation-copy missing: ${phrase}`);
}

const forbiddenCertainty = [
  /\bcertainly\b/i,
  /\bdefinitely\b/i,
  /\bproven\b/i,
  /\bdiagnos/i,
  /\byou should\b/i,
];
for (const file of [
  "packages/shared/lib/archive/archive-reputation-copy.ts",
  "packages/shared/lib/archive/archive-reputation-trust.ts",
  "packages/shared/lib/archive/archive-reputation-movement.ts",
  "apps/web/components/archive/ArchiveReputationCard.tsx",
]) {
  const src = read(file);
  for (const pattern of forbiddenCertainty) {
    if (pattern.test(src)) fail(`${file} contains forbidden certainty/coaching language`);
  }
}

const commandCenter = read("apps/web/components/archive/ArchiveCommandCenter.tsx");
const ccIndex = (label) => commandCenter.indexOf(label);
const order = [
  ["reputation", ccIndex("<ArchiveReputationCard")],
  ["trust", ccIndex("<WhyTheArchiveTrustsThis")],
  ["what changed", ccIndex("{ARCHIVE_BELIEF_WHAT_CHANGED_TITLE}")],
  ["timeline", ccIndex("<BeliefChangeTimeline")],
];
for (let i = 1; i < order.length; i++) {
  const [prevLabel, prevIdx] = order[i - 1];
  const [label, idx] = order[i];
  if (prevIdx < 0 || idx < 0) fail(`ArchiveCommandCenter missing section: ${label}`);
  if (prevIdx >= idx) {
    fail(`ArchiveCommandCenter order: ${prevLabel} must appear before ${label}`);
  }
}
if (!commandCenter.includes("WhyTheArchiveTrustsThis")) {
  fail("ArchiveCommandCenter must include WhyTheArchiveTrustsThis");
}
if (commandCenter.includes("BeliefSurvivalCard")) {
  fail("ArchiveCommandCenter should demote BeliefSurvivalCard to dossier (reputation first)");
}

const dossier = read("apps/web/components/archive/BeliefDossier.tsx");
const dossierRep = dossier.indexOf("ArchiveReputationCard");
const dossierBlind = dossier.indexOf("relatedBlindSpotHeadline");
if (dossierRep < 0 || dossier.indexOf("WhyTheArchiveTrustsThis") < 0) {
  fail("BeliefDossier must include reputation + trust sections");
}
if (dossierBlind >= 0 && dossierRep > dossierBlind) {
  fail("BeliefDossier reputation must appear above blind spot");
}

const discover = read("apps/web/app/discover/page.tsx");
if (!discover.includes("ArchiveReputationMovement")) {
  fail("Discover must include ArchiveReputationMovement");
}
if (!discover.includes("Archive reputation increased")) {
  const movement = read("packages/shared/lib/archive/archive-reputation-movement.ts");
  if (!movement.includes("Archive reputation increased")) {
    fail("discover reputation movement copy missing");
  }
}

if (!read("apps/web/components/archive/ArchiveCommandCenter.tsx").includes("ArchiveReputationCard")) {
  fail("Archive command center must render ArchiveReputationCard");
}
if (!read("apps/web/components/archive/ArchiveBeliefHeader.tsx").includes("buildArchiveBeliefObject")) {
  fail("ArchiveBeliefHeader must use belief object");
}
if (!read("apps/web/components/archive/BeliefDossier.tsx").includes("ArchiveReputationCard")) {
  fail("Belief Dossier must render ArchiveReputationCard");
}
if (discover.includes("ArchiveReputationCard") && !discover.includes("compact")) {
  fail("Discover must use ArchiveReputationMovement only, not full ArchiveReputationCard");
}

const beliefCopy = read("packages/shared/lib/archive/archive-belief-copy.ts");
if (!beliefCopy.includes("currently believes")) {
  fail("archive-belief-copy must use currently believes framing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-reputation"]) {
  fail("package.json missing validate:archive-reputation");
}

if (failures.length) {
  console.error("validate-archive-reputation failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-reputation ok");
