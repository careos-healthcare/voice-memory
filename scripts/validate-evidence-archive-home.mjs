#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "apps/web/app/archive-belief/page.tsx",
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
  "apps/web/components/archive/ArchiveBeliefCard.tsx",
  "apps/web/components/archive/BeliefChangeTimeline.tsx",
  "apps/web/components/product/EvidenceArchivePreview.tsx",
  "apps/web/components/retention/BeliefRecallPrompt.tsx",
  "packages/shared/lib/internal/belief-recall-report.ts",
  "apps/web/components/internal/BeliefRecallPanel.tsx",
  "apps/web/components/social-proof/ArchiveProofStories.tsx",
  "data/archive-proof-stories.json",
  "apps/web/components/retention/ReferralSharePrompt.tsx",
  "packages/shared/lib/retention/referral-share-prompt.ts",
  "apps/web/components/account/AccountSecondaryNav.tsx",
  "packages/shared/lib/archive/evidence-archive-home-copy.ts",
  "packages/shared/lib/product/evidence-archive-preview-copy.ts",
  "packages/shared/lib/product/archive-product-copy.ts",
  "apps/web/components/archive/ArchiveProductWayfinding.tsx",
  "apps/web/components/archive/ArchiveUtilitiesNav.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const homeCopy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/evidence-archive-home-copy.ts"),
  "utf8",
);
const productCopy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/archive-product-copy.ts"),
  "utf8",
);
for (const phrase of [
  "Your archive",
  "What your archive currently believes",
  "This is not a verdict",
  "watching the belief change",
  "Your archive needs a few comparison points",
  "Your archive would be hard to rebuild",
  "Check the state of your archive",
]) {
  const src =
    phrase.includes("Check the state") ? productCopy : homeCopy;
  if (!src.includes(phrase)) fail(`missing copy: ${phrase}`);
}
if (
  !productCopy.includes("See archive changes") &&
  !productCopy.includes("See what changed")
) {
  fail("product copy must link discover as archive changes");
}
if (
  !productCopy.includes("What changed since last time") &&
  !productCopy.includes("Here's what changed since your last visit.")
) {
  fail("product copy must explain discover change log");
}

const archiveHome = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"),
  "utf8",
);
for (const token of [
  "ArchiveCommandCenter",
  "ArchiveDetailsCollapsible",
  "ArchiveLoadingState",
]) {
  if (!archiveHome.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
}
const beliefBlock = archiveHome.slice(archiveHome.indexOf("<ArchiveCommandCenter"));
const sectionOrder = [
  "<ArchiveCommandCenter",
  "<BeliefDossier",
  "<EvidenceLocker",
  "<EvidenceSearch",
];
let lastIdx = -1;
for (const id of sectionOrder) {
  const idx = beliefBlock.indexOf(id);
  if (idx < 0) fail(`EvidenceArchiveHome missing section marker ${id}`);
  if (idx < lastIdx) fail(`EvidenceArchiveHome section order wrong at ${id}`);
  lastIdx = idx;
}
for (const token of [
  "ArchiveWorthStatement",
  "BeliefDossier",
  "EvidenceLocker",
  "EvidenceSearch",
  "ArchiveLossAversionPrompt",
]) {
  if (!archiveHome.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
}

const previewCopy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/evidence-archive-preview-copy.ts"),
  "utf8",
);
for (const phrase of [
  "One data point saved",
  "First working belief unlocked",
  "Add one more reflection",
]) {
  if (!previewCopy.includes(phrase)) fail(`missing preview: ${phrase}`);
}

const header = fs.readFileSync(path.join(ROOT, "apps/web/components/SiteHeader.tsx"), "utf8");
const simplicityNav = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/simplicity-mode.ts"),
  "utf8",
);
if (!header.includes("SIMPLICITY_PRIMARY_NAV")) fail("SiteHeader must use SIMPLICITY_PRIMARY_NAV");
for (const label of ["Record", "Archive", "Discover", "Account"]) {
  if (!simplicityNav.includes(`label: "${label}"`)) fail(`nav missing ${label}`);
}
const primaryNavBlock = simplicityNav.slice(
  simplicityNav.indexOf("SIMPLICITY_PRIMARY_NAV"),
  simplicityNav.indexOf("ARCHIVE_DETAIL_ROUTES"),
);
for (const demoted of ["/theories", "/insights", "/weekly"]) {
  if (primaryNavBlock.includes(`href: "${demoted}"`)) {
    fail(`demoted route must not be in SIMPLICITY_PRIMARY_NAV: ${demoted}`);
  }
}
if (!simplicityNav.includes("/archive-belief")) fail("nav must link archive-belief");

const returning = fs.readFileSync(path.join(ROOT, "packages/shared/lib/product/returning-home.ts"), "utf8");
if (!returning.includes("/archive-belief")) fail("returning home must use archive-belief");
if (!returning.includes("shouldAutoRedirectToArchiveBelief")) fail("archive redirect fn");

const paywall = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/billing/value-moment-paywall-copy.ts"),
  "utf8",
);
for (const phrase of [
  "Keep the archive evolving",
  "First working belief",
  "First archive view",
  "Full evidence timeline",
]) {
  if (!paywall.includes(phrase)) fail(`paywall copy missing: ${phrase}`);
}

const stories = JSON.parse(
  fs.readFileSync(path.join(ROOT, "data/archive-proof-stories.json"), "utf8"),
);
if (stories.label !== "Early tester notes") fail("proof stories label");
if (stories.stories?.some((s) => /\d+%|users love|thousands/i.test(s.quote))) {
  fail("proof stories must not contain fake stats");
}

const timeline = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/BeliefChangeTimeline.tsx"),
  "utf8",
);
if (!timeline.includes("data-dominant")) fail("timeline must support dominant mode");
if (!timeline.includes("evidenceQuoteCount")) fail("timeline must show evidence count");

const mobileRouter = fs.readFileSync(
  path.join(ROOT, "apps/mobile/lib/router/app_router.dart"),
  "utf8",
);
if (!mobileRouter.includes("/archive-belief")) fail("mobile route /archive-belief");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:evidence-archive-home")) fail("package.json script");

const forbiddenEngine = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"),
  "utf8",
);
for (const imp of ["insight-ingredient-optimizer", "pattern-detection/engine", "theory-generation/engine"]) {
  if (forbiddenEngine.includes(imp)) fail(`forbidden engine import: ${imp}`);
}

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-evidence-archive-home" } };
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
  clear: () => storage.clear(),
  get length() {
    return storage.size;
  },
  key: (i) => [...storage.keys()][i] ?? null,
};

const { clearBeliefRecallForEval, saveBeliefRecallLevel } = await import(
  "../packages/shared/lib/retention/belief-recall.ts"
);
const { buildBeliefRecallReport } = await import("../packages/shared/lib/internal/belief-recall-report.ts");
const { clearReferralShareForEval, meetsReferralShareEligibility } = await import(
  "../packages/shared/lib/retention/referral-share-prompt.ts"
);

clearBeliefRecallForEval();
const record = saveBeliefRecallLevel("yes_clearly");
assert.equal(record.level, "yes_clearly");
const recallReport = buildBeliefRecallReport();
assert.equal(recallReport.totalResponses, 1);

clearReferralShareForEval();
clearBeliefRecallForEval();
assert.equal(meetsReferralShareEligibility(), false);

if (failures.length) {
  console.error("validate-evidence-archive-home failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-evidence-archive-home ok");
