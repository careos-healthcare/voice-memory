#!/usr/bin/env node
/**
 * Progressive Archive Disclosure v1
 * L1 surfaces must not expose reputation / ownership / accuracy / survival / maturity / worth.
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
  "reputation",
  "ownership",
  "accuracy",
  "survival",
  "maturity",
  "worth",
];

const L1_SURFACE_FILES = [
  "components/archive/ProgressiveArchiveHome.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
  "components/archive/DiscoverWhatChanged.tsx",
  "components/archive/ArchiveDetailsCollapsible.tsx",
  "lib/billing/value-moment-paywall-copy.ts",
  "lib/onboarding/archive-onboarding-copy.ts",
  "lib/design/archive-copy-restraint.ts",
];

for (const rel of [
  "lib/archive/archive-disclosure-level.ts",
  "types/archive-disclosure-level.ts",
  "lib/archive/archive-disclosure-copy.ts",
  "components/archive/ProgressiveArchiveHome.tsx",
  "components/archive/AdvancedArchiveDetail.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
]) {
  mustExist(rel);
}

const levelModule = read("lib/archive/archive-disclosure-level.ts");
for (const level of ["L1_BASIC", "L2_ENGAGED", "L3_ADVANCED"]) {
  if (!levelModule.includes(level)) fail(`archive-disclosure-level missing ${level}`);
}
for (const fn of [
  "resolveArchiveDisclosureLevel",
  "recordArchiveHomeVisit",
  "markArchiveDetailOpened",
]) {
  if (!levelModule.includes(fn)) fail(`archive-disclosure-level missing ${fn}`);
}

const disclosureCopy = read("lib/archive/archive-disclosure-copy.ts");
for (const label of [
  "Archive detail",
  "Advanced Archive Detail",
  "Keep the archive evolving.",
]) {
  if (!disclosureCopy.includes(label)) {
    fail(`archive-disclosure-copy missing label: ${label}`);
  }
}

const evidenceHome = read("components/archive/EvidenceArchiveHome.tsx");
if (!evidenceHome.includes("ProgressiveArchiveHome")) {
  fail("EvidenceArchiveHome must use ProgressiveArchiveHome");
}
for (const demoted of [
  "ArchiveReductionV3Home",
  "BeliefDossier",
  "ArchiveReputationCard",
  "ArchiveOwnershipPanel",
  "ArchiveAccuracyTracker",
  "BeliefSurvivalCard",
  "ArchiveHealthLine",
  "ArchiveMaturityMeter",
]) {
  if (evidenceHome.includes(demoted)) {
    fail(`EvidenceArchiveHome must not surface ${demoted}`);
  }
}

const progressiveHome = read("components/archive/ProgressiveArchiveHome.tsx");
if (!progressiveHome.includes("archive-disclosure-level")) {
  fail("ProgressiveArchiveHome must use archive-disclosure-level");
}
for (const demoted of ["ArchiveHealthLine", "ArchiveReputationCard", "ArchiveDetailHub"]) {
  if (progressiveHome.includes(demoted)) {
    fail(`ProgressiveArchiveHome must not include ${demoted}`);
  }
}

const advanced = read("components/archive/AdvancedArchiveDetail.tsx");
if (!advanced.includes("ARCHIVE_ADVANCED_DETAIL_EYEBROW")) {
  fail("AdvancedArchiveDetail must show Advanced Archive Detail eyebrow");
}

const collapsible = read("components/archive/ArchiveDetailsCollapsible.tsx");
if (!collapsible.includes("markArchiveDetailOpened")) {
  fail("ArchiveDetailsCollapsible must mark archive detail opened");
}
if (!collapsible.includes("AdvancedArchiveDetail")) {
  fail("ArchiveDetailsCollapsible must render AdvancedArchiveDetail");
}

const paywall = read("lib/billing/value-moment-paywall-copy.ts");
if (
  !paywall.includes("Keep the archive evolving") &&
  !paywall.includes("archive-disclosure-copy")
) {
  fail("paywall must use Keep the archive evolving headline");
}

const onboarding = read("lib/onboarding/archive-onboarding-copy.ts");
if (!onboarding.includes("forms beliefs")) {
  fail("onboarding must mention beliefs forming");
}
if (!onboarding.includes("Those beliefs change.")) {
  fail("onboarding must include Those beliefs change.");
}

for (const rel of L1_SURFACE_FILES) {
  const text = read(rel);
  for (const word of FORBIDDEN) {
    if (new RegExp(`\\b${word}\\b`, "i").test(text)) {
      fail(`${rel} must not expose "${word}" on L1 surfaces`);
    }
  }
}

const hub = read("components/archive/ArchiveDetailHub.tsx");
for (const forbiddenLabel of [
  "Belief Survival",
  "Archive Accuracy",
  "Archive Reputation",
  "Archive Ownership",
]) {
  if (hub.includes(forbiddenLabel)) {
    fail(`ArchiveDetailHub must not label links as ${forbiddenLabel}`);
  }
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:progressive-disclosure"]) {
  fail("package.json missing validate:progressive-disclosure");
}

if (failures.length) {
  console.error("validate-progressive-disclosure failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-progressive-disclosure ok");
