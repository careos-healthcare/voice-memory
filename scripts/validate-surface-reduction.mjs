#!/usr/bin/env node
/**
 * Surface Reduction System v2
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
  "lib/product/archive-relevance.ts",
  "lib/product/archive-feature-justification.ts",
  "components/archive/ArchiveDetailHub.tsx",
  "app/archive-detail/page.tsx",
  "components/archive/ReflectionLogPanel.tsx",
  "scripts/generate-archive-relevance-report.mjs",
  "scripts/validate-surface-reduction.mjs",
];

for (const rel of required) mustExist(rel);

spawnSync("node", ["--import", "tsx", "scripts/generate-archive-relevance-report.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});

if (!fs.existsSync(path.join(ROOT, "docs/ARCHIVE_RELEVANCE_REPORT.md"))) {
  fail("docs/ARCHIVE_RELEVANCE_REPORT.md not generated");
}

const simplicity = read("lib/product/simplicity-mode.ts");
for (const label of ["Record", "Archive", "Archive Activity", "Account"]) {
  if (!simplicity.includes(`label: "${label}"`)) fail(`primary nav missing ${label}`);
}
if (simplicity.includes('label: "Search"') && simplicity.includes("SIMPLICITY_PRIMARY_NAV")) {
  const block = simplicity.slice(
    simplicity.indexOf("SIMPLICITY_PRIMARY_NAV"),
    simplicity.indexOf("ARCHIVE_DETAIL_ROUTES"),
  );
  if (block.includes('label: "Search"')) fail("Search must not be in SIMPLICITY_PRIMARY_NAV");
}
if (simplicity.includes('label: "Discover"')) {
  const block = simplicity.slice(
    simplicity.indexOf("SIMPLICITY_PRIMARY_NAV"),
    simplicity.indexOf("ARCHIVE_DETAIL_ROUTES"),
  );
  if (block.includes('label: "Discover"')) fail('Use "Archive Activity" not Discover in primary nav');
}

const header = read("components/SiteHeader.tsx");
if (!header.includes("SIMPLICITY_PRIMARY_NAV")) fail("SiteHeader must use SIMPLICITY_PRIMARY_NAV");

const commandCenter = read("components/archive/ArchiveCommandCenter.tsx");
for (const token of [
  "ArchiveReputationCard",
  "WhyTheArchiveTrustsThis",
  "ARCHIVE_BELIEF_WHAT_CHANGED_TITLE",
  "justificationFor",
]) {
  if (!commandCenter.includes(token)) fail(`ArchiveCommandCenter missing ${token}`);
}
for (const removed of ["ArchiveReductionSections", "ArchiveMeaningSummary"]) {
  if (commandCenter.includes(removed)) {
    fail(`ArchiveCommandCenter must not include demoted section: ${removed}`);
  }
}
for (const required of ["BeliefChangeTimeline", "ArchiveBeliefEvidenceSection"]) {
  if (!commandCenter.includes(required)) {
    fail(`ArchiveCommandCenter must include belief-centric section: ${required}`);
  }
}

const discover = read("app/discover/page.tsx");
for (const dup of [
  "ArchiveBeliefCard",
  "ArchiveReputationCard",
  "WhyTheArchiveTrustsThis",
  "BeliefDossier",
  "ArchiveAssetCard",
  "WhyPeopleReturn",
]) {
  if (discover.includes(dup)) fail(`Discover must not duplicate archive surface: ${dup}`);
}
if (!discover.includes("TheoryChangeFeed") || !discover.includes("ArchiveReputationMovement")) {
  fail("Discover must own change/movement feeds");
}

const memory = read("app/memory/page.tsx");
if (!memory.includes("ReflectionLogPanel")) fail("memory must use ReflectionLogPanel");
for (const dup of [
  "SessionMovementSummary",
  "ArchiveValueBanner",
  "CurrentArchiveBeliefStrip",
  "ActivationTheoryPreview",
]) {
  if (memory.includes(dup)) fail(`Reflection log must not duplicate: ${dup}`);
}

const home = read("components/archive/EvidenceArchiveHome.tsx");
if (!home.includes("ArchiveDetailHub")) fail("archive home must link ArchiveDetailHub");

const justification = read("lib/product/archive-feature-justification.ts");
for (const key of [
  "ArchiveCommandCenter",
  "ArchiveReputationCard",
  "BeliefChangeTimeline",
  "ArchiveDetailHub",
  "ReflectionLog",
]) {
  if (!justification.includes(`${key}:`)) fail(`justification missing ${key}`);
}
if (!justification.includes("archiveContributionReason")) {
  fail("archive-feature-justification must define archiveContributionReason");
}

const classifyCheck = spawnSync(
  "node",
  [
    "--import",
    "tsx",
    "-e",
    `
import { classifySurface } from './lib/product/archive-relevance.ts';
const checks = [
  ['/archive-belief', 'core'],
  ['/discover', 'core'],
  ['/memory', 'utility'],
];
for (const [route, level] of checks) {
  const c = classifySurface(route);
  if (c.level !== level) {
    console.error('classify failed', route, c.level, 'expected', level);
    process.exit(1);
  }
}
if (!classifySurface('/search').hide) process.exit(1);
`,
  ],
  { cwd: ROOT, encoding: "utf8" },
);
if (classifyCheck.status !== 0) fail("classifySurface rules failed");

const mobile = read("apps/voicememory_mobile/lib/widgets/main_shell.dart");
if (!mobile.includes("label: 'Changes'")) fail("mobile nav must label Changes");
if (mobileShellDiscover(mobile)) fail("mobile must not use Discover label");
function mobileShellDiscover(src) {
  return /label:\s*'Discover'/.test(src);
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:surface-reduction"]) fail("missing validate:surface-reduction script");
if (!pkg.scripts["generate:archive-relevance-report"]) {
  fail("missing generate:archive-relevance-report script");
}

if (failures.length) {
  console.error("validate-surface-reduction failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-surface-reduction passed");
