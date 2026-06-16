#!/usr/bin/env node
/**
 * Archive Ownership Layer v2 — milestones + history summary on key surfaces.
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
  "types/archive-ownership-v2.ts",
  "lib/archive/archive-ownership-v2.ts",
  "components/archive/ArchiveMilestones.tsx",
  "components/archive/ArchiveHistorySummary.tsx",
];

for (const rel of required) mustExist(rel);

const lib = read("lib/archive/archive-ownership-v2.ts");
for (const phrase of [
  "ARCHIVE_MILESTONES_HEADLINE",
  "Your archive now contains:",
  "First belief",
  "of evidence",
  "belief change",
  "buildArchiveMilestones",
  "buildArchiveHistorySummary",
  "This archive has been evolving for",
  "This belief survived",
  "This archive contains evidence from",
]) {
  if (!lib.includes(phrase)) fail(`archive-ownership-v2 missing: ${phrase}`);
}

const milestones = read("components/archive/ArchiveMilestones.tsx");
if (!milestones.includes('data-testid="archive-milestones"')) {
  fail("ArchiveMilestones missing test id");
}
if (!milestones.includes("buildArchiveMilestones")) {
  fail("ArchiveMilestones must call buildArchiveMilestones");
}

const history = read("components/archive/ArchiveHistorySummary.tsx");
if (!history.includes('data-testid="archive-history-summary"')) {
  fail("ArchiveHistorySummary missing test id");
}
if (!history.includes("buildArchiveHistorySummary")) {
  fail("ArchiveHistorySummary must call buildArchiveHistorySummary");
}

const surfaces = [
  ["components/archive/EvidenceArchiveHome.tsx", "Archive"],
  ["app/account/page.tsx", "Account"],
  ["components/archive/ArchiveOwnershipPanel.tsx", "Export"],
  ["components/billing/ValueMomentPaywall.tsx", "Paywall"],
];

for (const [file, label] of surfaces) {
  const src = read(file);
  if (!src.includes("ArchiveMilestones")) {
    fail(`${label} surface (${file}) must render ArchiveMilestones`);
  }
  if (!src.includes("ArchiveHistorySummary")) {
    fail(`${label} surface (${file}) must render ArchiveHistorySummary`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-ownership-v2"]) {
  fail("package.json missing validate:archive-ownership-v2");
}

if (failures.length) {
  console.error("validate-archive-ownership-v2 failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-ownership-v2 ok");
