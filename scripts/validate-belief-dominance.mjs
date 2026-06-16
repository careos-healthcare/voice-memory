#!/usr/bin/env node
/**
 * Archive Belief Dominance v2
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
  "lib/product/belief-dominance-copy.ts",
  "components/archive/ArchiveBeliefStickyBar.tsx",
  "components/archive/ArchiveHealthSummary.tsx",
  "scripts/validate-belief-dominance.mjs",
];

for (const rel of required) mustExist(rel);

const dominanceCopy = read("lib/product/belief-dominance-copy.ts");
for (const token of [
  "BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF",
  "BELIEF_DOMINANCE_ARCHIVE_CHANGE",
  "BELIEF_DOMINANCE_ARCHIVE_TRUST",
  "COMPETING_PRODUCT_HEADLINES",
]) {
  if (!dominanceCopy.includes(token)) fail(`belief-dominance-copy missing ${token}`);
}

const sticky = read("components/archive/ArchiveBeliefStickyBar.tsx");
if (!sticky.includes("buildArchiveBeliefObject")) {
  fail("ArchiveBeliefStickyBar must use buildArchiveBeliefObject");
}
if (!sticky.includes("sticky") || !sticky.includes("top-0")) {
  fail("ArchiveBeliefStickyBar must be sticky on scroll");
}

for (const page of [
  "app/archive-belief/page.tsx",
  "app/discover/page.tsx",
  "app/archive-detail/page.tsx",
  "app/memory/page.tsx",
]) {
  const src = read(page);
  if (!src.includes("ArchiveBeliefStickyBar")) {
    fail(`${page} must render ArchiveBeliefStickyBar`);
  }
}

const archiveHome = read("components/archive/EvidenceArchiveHome.tsx");
if (!archiveHome.includes("ArchiveHealthSummary")) {
  fail("EvidenceArchiveHome must render ArchiveHealthSummary");
}
const healthIdx = archiveHome.indexOf("ArchiveHealthSummary");
const commandIdx = archiveHome.indexOf("ArchiveCommandCenter");
if (healthIdx < 0 || commandIdx < 0 || healthIdx > commandIdx) {
  fail("ArchiveHealthSummary must appear before ArchiveCommandCenter on archive home");
}

const blindSpotsPage = read("app/blind-spots/page.tsx");
const blindSpotCopy = read("lib/blind-spots/blind-spot-copy.ts");
if (
  !blindSpotsPage.includes("Evidence for belief") &&
  !(
    blindSpotsPage.includes("BLIND_SPOT_PAGE") &&
    blindSpotCopy.includes("Evidence for belief")
  )
) {
  fail("blind-spots must frame as Evidence for belief");
}
const discoverFraming =
  read("app/discover/page.tsx") + read("lib/product/archive-product-copy.ts");
if (!discoverFraming.includes("Archive Activity")) {
  fail("discover must frame as Archive Activity");
}
if (!read("app/theories/page.tsx").includes("BELIEF_DOMINANCE_ARCHIVE_TRUST")) {
  fail("theories page must reference Archive trust reframe");
}
if (!read("app/insights/page.tsx").includes("BELIEF_DOMINANCE_ARCHIVE_CHANGE")) {
  fail("insights page must reference Archive change reframe");
}

for (const headline of [
  "Blind Spot",
  "Blind Spots",
  "Pattern Review",
  '"Theories"',
  "title: \"Insights\"",
  "What keeps returning",
]) {
  if (read("components/archive/ArchiveDetailHub.tsx").includes(headline)) {
    fail(`ArchiveDetailHub must not promote competing headline: ${headline}`);
  }
}

function scanPublicPages(dir) {
  const abs = path.join(ROOT, dir);
  for (const name of fs.readdirSync(abs)) {
    const rel = path.join(dir, name);
    const full = path.join(abs, name);
    if (fs.statSync(full).isDirectory()) {
      if (name === "internal" || name === "debug" || name === "api") continue;
      scanPublicPages(rel);
      continue;
    }
    if (!name.endsWith(".tsx")) continue;
    const src = fs.readFileSync(full, "utf8");
    if (!src.includes("text-3xl")) continue;
    for (const banned of [
      "Blind Spot",
      "Blind Spots",
      "Pattern Review",
      ">Theories<",
      ">Theory<",
      ">Insights<",
      "What keeps returning",
    ]) {
      if (src.includes(banned)) {
        fail(`public page ${rel} has competing text-3xl headline: ${banned}`);
      }
    }
  }
}

scanPublicPages("app");

const theoriesCopy = read("lib/archive/archive-belief-copy.ts");
if (!theoriesCopy.includes("BELIEF_DOMINANCE_ARCHIVE_TRUST")) {
  fail("theories page copy must reframe to Archive trust");
}

const productCopy = read("lib/product/archive-product-copy.ts");
if (productCopy.includes('BLIND_SPOTS_PAGE_TITLE = "Archive Insight"')) {
  fail("BLIND_SPOTS_PAGE_TITLE must use Evidence for belief framing");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:belief-dominance"]) {
  fail("package.json missing validate:belief-dominance script");
}

if (failures.length) {
  console.error("validate-belief-dominance failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-belief-dominance passed");
