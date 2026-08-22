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
  "packages/shared/lib/product/archive-positioning.ts",
  "packages/shared/lib/archive/what-is-my-archive.ts",
  "packages/shared/lib/archive/archive-difference-examples.ts",
  "packages/shared/lib/archive/first-session-value.ts",
  "packages/shared/lib/archive/why-people-return-copy.ts",
  "packages/shared/lib/founder-test/archive-understanding-validation.ts",
  "apps/web/components/archive/WhatIsMyArchive.tsx",
  "apps/web/components/archive/ArchiveDifferenceCard.tsx",
  "apps/web/components/archive/WhyPeopleReturn.tsx",
  "apps/web/components/archive/FirstSessionValueCard.tsx",
  "apps/web/components/archive/ArchiveVisualModel.tsx",
  "apps/web/components/internal/ArchiveUnderstandingPanel.tsx",
  "apps/mobile/lib/widgets/archive_quick_explain_card.dart",
  "scripts/validate-archive-language.mjs",
  "scripts/validate-instant-understanding.mjs",
];

for (const rel of required) mustExist(rel);

const positioning = read("packages/shared/lib/product/archive-positioning.ts");
const canonical =
  "ArchiveMe keeps track of what your archive believes about you and how that changes over time.";
if (!positioning.includes(canonical)) fail("archive-positioning missing canonical sentence");

if (!read("apps/web/components/archive/ArchiveIdentityBar.tsx").includes("VOICEMEMORY_ARCHIVE_POSITIONING")) {
  fail("ArchiveIdentityBar must use VOICEMEMORY_ARCHIVE_POSITIONING");
}

for (const page of [
  "apps/web/app/page.tsx",
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
  "apps/web/components/onboarding/ArchiveOnboarding.tsx",
  "apps/web/components/Recorder.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/app/pricing/PricingPageClient.tsx",
]) {
  const src = read(page);
  if (!src.includes("WhatIsMyArchive") && page !== "apps/web/app/discover/page.tsx" && page !== "apps/web/app/pricing/PricingPageClient.tsx") {
    fail(`${page} must include WhatIsMyArchive`);
  }
}

if (!read("apps/web/components/Recorder.tsx").includes("FirstSessionValueCard")) {
  fail("Recorder must show FirstSessionValueCard after first save");
}
if (!read("apps/web/components/onboarding/ArchiveOnboarding.tsx").includes("ArchiveDifferenceCard")) {
  fail("ArchiveOnboarding must include ArchiveDifferenceCard");
}
if (!read("apps/web/app/page.tsx").includes("ArchiveDifferenceCard")) {
  fail("home must include ArchiveDifferenceCard");
}
if (!read("apps/web/app/pricing/PricingPageClient.tsx").includes("ArchiveVisualModel")) {
  fail("pricing must include ArchiveVisualModel");
}
if (!read("apps/web/components/archive/EvidenceArchiveHome.tsx").includes("WhyPeopleReturn")) {
  fail("archive home must include WhyPeopleReturn");
}
if (read("apps/web/app/discover/page.tsx").includes("WhyPeopleReturn")) {
  fail("Discover must not duplicate WhyPeopleReturn — archive owns understanding");
}

const whatIs = read("packages/shared/lib/archive/what-is-my-archive.ts");
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
  "packages/shared/lib/archive/what-is-my-archive.ts",
  "packages/shared/lib/archive/first-session-value.ts",
  "packages/shared/lib/archive/archive-difference-examples.ts",
]) {
  const src = read(file);
  for (const token of forbidden) {
    if (src.includes(token)) fail(`${file} must not add intelligence: ${token}`);
  }
}

const mobile = read("apps/mobile/lib/screens/archive_belief_screen.dart");
if (!mobile.includes("ArchiveQuickExplainCard")) {
  fail("mobile archive home must include ArchiveQuickExplainCard");
}

const founder = read("apps/web/components/internal/FounderTestPanel.tsx");
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
