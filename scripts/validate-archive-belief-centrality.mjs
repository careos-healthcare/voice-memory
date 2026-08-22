#!/usr/bin/env node
/**
 * Archive Belief Centric Architecture v1
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

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
  "packages/shared/types/archive-belief-object.ts",
  "packages/shared/lib/archive/build-archive-belief-object.ts",
  "apps/web/components/archive/ArchiveBeliefHeader.tsx",
  "packages/shared/lib/product/archive-surface-ownership.ts",
  "packages/shared/lib/product/archive-belief-justification.ts",
  "apps/web/components/internal/ArchiveBeliefCenterPanel.tsx",
  "scripts/validate-archive-belief-centrality.mjs",
];

for (const rel of required) mustExist(rel);

const beliefType = read("packages/shared/types/archive-belief-object.ts");
for (const field of [
  "belief:",
  "confidence:",
  "reputation:",
  "whatChanged:",
  "trustReasons:",
  "timelinePoints:",
]) {
  if (!beliefType.includes(field)) fail(`ArchiveBeliefObject missing ${field}`);
}

if (!read("packages/shared/lib/archive/build-archive-belief-object.ts").includes("buildArchiveBeliefObject")) {
  fail("missing buildArchiveBeliefObject");
}

const header = read("apps/web/components/archive/ArchiveBeliefHeader.tsx");
if (!header.includes("buildArchiveBeliefObject")) {
  fail("ArchiveBeliefHeader must use buildArchiveBeliefObject");
}
if (
  !header.includes("ARCHIVE_BELIEF_HEADER_TITLE") &&
  !header.includes("Current Archive Belief")
) {
  fail("ArchiveBeliefHeader missing title");
}

function beliefHeaderFirst(file, label) {
  const src = read(file);
  const headerIdx = src.indexOf("ArchiveBeliefHeader");
  if (headerIdx < 0) {
    fail(`${label} must include ArchiveBeliefHeader`);
    return;
  }
  const before = src.slice(0, headerIdx);
  const blockers = ["ArchiveCommandCenter", "ArchivePageBlueprint", "ArchiveIdentityBar"];
  for (const token of blockers) {
    const idx = before.indexOf(token);
    if (idx >= 0) fail(`${label}: ${token} must not render above ArchiveBeliefHeader`);
  }
}

beliefHeaderFirst("apps/web/components/archive/EvidenceArchiveHome.tsx", "archive home");
beliefHeaderFirst("apps/web/app/discover/page.tsx", "discover");
beliefHeaderFirst("apps/web/components/archive/BeliefDossier.tsx", "belief dossier");
beliefHeaderFirst("apps/web/app/archive-detail/page.tsx", "archive detail");

const discover = read("apps/web/app/discover/page.tsx");
for (const dup of [
  "ArchiveBeliefCard",
  "WhyTheArchiveTrustsThis",
  "BeliefDossier",
  "EvidenceLocker",
  "ArchiveAccuracyTracker",
]) {
  if (discover.includes(dup)) fail(`Discover duplicates archive surface: ${dup}`);
}
if (!discover.includes("TheoryChangeFeed")) fail("Discover must own change feed");

const commandCenter = read("apps/web/components/archive/ArchiveCommandCenter.tsx");
if (!commandCenter.includes("BeliefChangeTimeline")) {
  fail("Archive must own timeline in command center");
}
if (!commandCenter.includes("WhyTheArchiveTrustsThis")) {
  fail("Archive must own trust");
}
if (!commandCenter.includes("ArchiveBeliefEvidenceSection")) {
  fail("Archive must own evidence");
}
if (commandCenter.includes("ArchiveBeliefHeader")) {
  fail("Belief header is separate from command center body");
}

const memory = read("apps/web/app/memory/page.tsx");
if (!memory.includes("ReflectionLogPanel")) fail("memory must use ReflectionLogPanel");

const justification = read("packages/shared/lib/product/archive-belief-justification.ts");
if (!justification.includes("supportsBelief")) fail("belief justification flags required");
const hideCheck = spawnSync(
  "node",
  [
    "--import",
    "tsx",
    "-e",
    `import { featuresMissingBeliefCentricSupport } from './lib/product/archive-belief-justification.ts';
const missing = featuresMissingBeliefCentricSupport();
if (missing.length) { console.error(missing.join(',')); process.exit(1); }`,
  ],
  { cwd: ROOT, encoding: "utf8" },
);
if (hideCheck.status !== 0) {
  fail(`features missing belief-centric support: ${hideCheck.stderr || hideCheck.stdout}`);
}

if (!read("packages/shared/lib/blind-spots/blind-spot-copy.ts").includes("Evidence for belief")) {
  fail("blind spot copy must reframe to Evidence for belief");
}
const blindCopy = read("packages/shared/lib/blind-spots/blind-spot-copy.ts");
if (
  !blindCopy.includes("EVIDENCE_FOR_BELIEF_LEAD") &&
  !blindCopy.includes("one reason the archive currently believes")
) {
  fail("evidence-for-belief lead must anchor to archive belief");
}

if (!read("apps/web/components/archive/ArchiveDetailHub.tsx").includes("Belief Survival")) {
  fail("ArchiveDetailHub must link Belief Survival");
}
if (!read("apps/web/components/archive/ArchiveDetailHub.tsx").includes("Archive Silence")) {
  fail("ArchiveDetailHub must link Archive Silence");
}

if (!read("apps/web/components/internal/FounderTestPanel.tsx").includes("ArchiveBeliefCenterPanel")) {
  fail("founder-test must include ArchiveBeliefCenterPanel");
}

const mobile = read("apps/mobile/lib/screens/archive_belief_screen.dart");
if (!mobile.includes("Archive detail")) fail("mobile archive must link archive detail");
if (!mobile.includes("ArchiveBeliefHeaderMobile")) {
  fail("mobile archive must render ArchiveBeliefHeaderMobile first");
}
const mobileQuickIdx = mobile.indexOf("ArchiveQuickExplainCard");
const mobileBeliefHeaderIdx = mobile.indexOf("ArchiveBeliefHeaderMobile");
if (
  mobileQuickIdx >= 0 &&
  mobileBeliefHeaderIdx >= 0 &&
  mobileBeliefHeaderIdx > mobileQuickIdx
) {
  fail("ArchiveBeliefHeaderMobile must appear before ArchiveQuickExplainCard on mobile");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-belief-centrality"]) {
  fail("package.json missing validate:archive-belief-centrality");
}

const buildCheck = spawnSync(
  "node",
  [
    "--import",
    "tsx",
    "-e",
    `import { buildArchiveBeliefObject } from './lib/archive/build-archive-belief-object.ts';
const o = buildArchiveBeliefObject([]);
if (o !== null) process.exit(1);`,
  ],
  { cwd: ROOT, encoding: "utf8" },
);
if (buildCheck.status !== 0) fail("buildArchiveBeliefObject empty check failed");

const forbidden = ["openai", "generateTheory", "pattern-engine", "llm"];
for (const file of ["packages/shared/lib/archive/build-archive-belief-object.ts"]) {
  for (const token of forbidden) {
    if (read(file).includes(token)) fail(`${file} must not add intelligence: ${token}`);
  }
}

if (failures.length) {
  console.error("validate-archive-belief-centrality failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-belief-centrality passed");
