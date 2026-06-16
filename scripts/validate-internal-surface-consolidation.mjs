#!/usr/bin/env node
/**
 * Internal Surface Consolidation v3
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

for (const rel of [
  "lib/internal/internal-archive-registry.ts",
  "lib/internal/delete-candidate-detector.ts",
  "lib/internal/founder-focus-score.ts",
  "lib/internal/launch-readiness.ts",
  "app/internal/page.tsx",
  "app/internal/activation/page.tsx",
  "app/internal/return/page.tsx",
  "app/internal/conversion/page.tsx",
  "app/internal/launch/page.tsx",
  "components/internal/InternalCommandCenter.tsx",
  "components/internal/FounderInternalNav.tsx",
]) {
  mustExist(rel);
}

const registry = read("lib/internal/internal-archive-registry.ts");
for (const status of ["ACTIVE", "ARCHIVED", "DELETE_CANDIDATE"]) {
  if (!registry.includes(status)) fail(`registry missing status ${status}`);
}
for (const pillar of ["activation", "return", "conversion", "distribution", "mobile"]) {
  if (!registry.includes(`"${pillar}"`)) fail(`registry missing pillar ${pillar}`);
}
for (const field of ["decisionQuestion", "decisionAction", "discoverable"]) {
  if (!registry.includes(field)) fail(`registry missing ${field}`);
}

const commandCenter = read("app/internal/page.tsx");
if (!commandCenter.includes("InternalCommandCenter")) {
  fail("/internal must render InternalCommandCenter");
}

const nav = read("components/internal/FounderInternalNav.tsx");
if (nav.includes("/internal/organic-referral") || nav.includes("/internal/archive")) {
  fail("FounderInternalNav must not link archived dashboards");
}
if (!nav.includes("/internal") || !nav.includes("/internal/launch")) {
  fail("FounderInternalNav must link command center and launch");
}

const returnPage = read("app/internal/return/page.tsx");
for (const panel of [
  "ArchiveAttachmentPanel",
  "BeliefRecallPanel",
  "OrganicReferralPanel",
  "ReturnTriggerPanel",
]) {
  if (!returnPage.includes(panel)) fail(`return hub missing ${panel}`);
}

const conversionPage = read("app/internal/conversion/page.tsx");
if (!conversionPage.includes("PaywallAttributionPanel")) {
  fail("conversion hub missing PaywallAttributionPanel");
}

const distributionPage = read("app/internal/distribution/page.tsx");
if (!distributionPage.includes("DistributionReportPanel")) {
  fail("distribution hub missing DistributionReportPanel");
}

const launch = read("app/internal/launch/page.tsx");
for (const verdict of ["NOT_READY", "ALMOST_READY", "READY"]) {
  if (!launch.includes(verdict) && !read("lib/internal/launch-readiness.ts").includes(verdict)) {
    fail(`launch readiness missing verdict ${verdict}`);
  }
}

const scoreCheck = spawnSync(
  "node",
  [
    "--import",
    "tsx",
    "-e",
    `import {
  getDiscoverableInternalRoutes,
  getActiveInternalArchiveRecords,
  getInternalArchiveRegistry,
  internalSurfaceReductionRatio,
  assertActivePanelHasDecision,
} from './lib/internal/internal-archive-registry.ts';
import { buildFounderFocusScore, FOUNDER_FOCUS_SCORE_TARGET } from './lib/internal/founder-focus-score.ts';

const discoverable = getDiscoverableInternalRoutes();
const active = getActiveInternalArchiveRecords();
const all = getInternalArchiveRegistry();
const focus = buildFounderFocusScore();

if (discoverable.length > 10) {
  console.error('discoverable routes', discoverable.length, 'must be <= 10');
  process.exit(1);
}
if (active.length > 12) {
  console.error('active dashboards', active.length, 'must be <= 12');
  process.exit(1);
}
for (const row of active) {
  if (!assertActivePanelHasDecision(row)) {
    console.error('ACTIVE panel missing decision:', row.route);
    process.exit(1);
  }
}
const reduction = internalSurfaceReductionRatio();
if (reduction < 0.7) {
  console.error('surface reduction', reduction, 'must be >= 0.7');
  process.exit(1);
}
console.log('discoverable:', discoverable.length);
console.log('active:', active.length);
console.log('archived+delete:', all.filter(r => r.status !== 'ACTIVE').length);
console.log('reduction:', Math.round(reduction * 100) + '%');
console.log('FounderFocusScore:', focus.score, 'target', FOUNDER_FOCUS_SCORE_TARGET);`,
  ],
  { cwd: ROOT, encoding: "utf8" },
);

if (scoreCheck.status !== 0) {
  fail(scoreCheck.stderr || scoreCheck.stdout || "consolidation score check failed");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:internal-surface-consolidation"]) {
  fail("package.json missing validate:internal-surface-consolidation");
}

if (failures.length) {
  console.error("validate-internal-surface-consolidation failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log(scoreCheck.stdout.trim());
console.log("validate-internal-surface-consolidation ok");
