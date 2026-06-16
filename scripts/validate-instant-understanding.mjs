#!/usr/bin/env node
/**
 * Instant Archive Understanding Layer v1
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
  "lib/product/archive-positioning.ts",
  "lib/archive/what-is-my-archive.ts",
  "lib/archive/archive-difference-examples.ts",
  "lib/archive/first-session-value.ts",
  "lib/archive/why-people-return-copy.ts",
  "lib/founder-test/archive-understanding-validation.ts",
  "components/archive/WhatIsMyArchive.tsx",
  "components/archive/ArchiveDifferenceCard.tsx",
  "components/archive/WhyPeopleReturn.tsx",
  "components/archive/FirstSessionValueCard.tsx",
  "components/archive/ArchiveVisualModel.tsx",
  "components/internal/ArchiveUnderstandingPanel.tsx",
  "apps/voicememory_mobile/lib/widgets/archive_quick_explain_card.dart",
  "scripts/validate-archive-language.mjs",
  "scripts/validate-instant-understanding.mjs",
];

for (const rel of required) mustExist(rel);

const positioning = read("lib/product/archive-positioning.ts");
const canonical =
  "ArchiveMe keeps track of what your archive believes about you and how that changes over time.";
if (!positioning.includes(canonical)) fail("archive-positioning missing canonical sentence");

if (!read("components/archive/ArchiveIdentityBar.tsx").includes("VOICEMEMORY_ARCHIVE_POSITIONING")) {
  fail("ArchiveIdentityBar must use VOICEMEMORY_ARCHIVE_POSITIONING");
}

for (const page of [
  "app/page.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
  "components/onboarding/ArchiveOnboarding.tsx",
  "components/Recorder.tsx",
  "app/discover/page.tsx",
  "app/pricing/PricingPageClient.tsx",
]) {
  const src = read(page);
  if (!src.includes("WhatIsMyArchive") && page !== "app/discover/page.tsx" && page !== "app/pricing/PricingPageClient.tsx") {
    fail(`${page} must include WhatIsMyArchive`);
  }
}

if (!read("components/Recorder.tsx").includes("FirstSessionValueCard")) {
  fail("Recorder must show FirstSessionValueCard after first save");
}
if (!read("components/onboarding/ArchiveOnboarding.tsx").includes("ArchiveDifferenceCard")) {
  fail("ArchiveOnboarding must include ArchiveDifferenceCard");
}
if (!read("app/page.tsx").includes("ArchiveDifferenceCard")) {
  fail("home must include ArchiveDifferenceCard");
}
if (!read("app/pricing/PricingPageClient.tsx").includes("ArchiveVisualModel")) {
  fail("pricing must include ArchiveVisualModel");
}
if (!read("components/archive/EvidenceArchiveHome.tsx").includes("WhyPeopleReturn")) {
  fail("archive home must include WhyPeopleReturn");
}
if (read("app/discover/page.tsx").includes("WhyPeopleReturn")) {
  fail("Discover must not duplicate WhyPeopleReturn — archive owns understanding");
}

const whatIs = read("lib/archive/what-is-my-archive.ts");
for (const phrase of [
  "Your archive is building a view of you.",
  "Collecting evidence",
  "Testing beliefs",
  "Tracking belief changes",
]) {
  if (!whatIs.includes(phrase)) fail(`what-is-my-archive missing: ${phrase}`);
}

const forbidden = ["openai", "generateTheory", "pattern-engine", "SemanticSearch", "llm"];
for (const file of [
  "lib/archive/what-is-my-archive.ts",
  "lib/archive/first-session-value.ts",
  "lib/archive/archive-difference-examples.ts",
]) {
  const src = read(file);
  for (const token of forbidden) {
    if (src.includes(token)) fail(`${file} must not add intelligence: ${token}`);
  }
}

const mobile = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
if (!mobile.includes("ArchiveQuickExplainCard")) {
  fail("mobile archive home must include ArchiveQuickExplainCard");
}

const founder = read("components/internal/FounderTestPanel.tsx");
if (!founder.includes("ArchiveUnderstandingPanel")) {
  fail("founder-test panel must include ArchiveUnderstandingPanel");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:instant-understanding"]) {
  fail("package.json missing validate:instant-understanding");
}
if (!pkg.scripts["validate:archive-language"]) {
  fail("package.json missing validate:archive-language");
}

spawnSync("node", ["scripts/validate-archive-language.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});

if (failures.length) {
  console.error("validate-instant-understanding failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-instant-understanding passed");
