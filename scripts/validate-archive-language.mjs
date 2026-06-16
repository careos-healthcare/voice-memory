#!/usr/bin/env node
/**
 * User-facing archive language — instant-understanding surfaces + primary pages.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const MUST_BE_CLEAN = [
  "lib/product/archive-positioning.ts",
  "lib/archive/what-is-my-archive.ts",
  "lib/archive/archive-difference-examples.ts",
  "lib/archive/first-session-value.ts",
  "lib/archive/why-people-return-copy.ts",
  "components/archive/WhatIsMyArchive.tsx",
  "components/archive/ArchiveDifferenceCard.tsx",
  "components/archive/WhyPeopleReturn.tsx",
  "components/archive/FirstSessionValueCard.tsx",
  "components/archive/ArchiveVisualModel.tsx",
  "components/archive/ArchiveIdentityBar.tsx",
  "components/onboarding/ArchiveOnboarding.tsx",
  "apps/voicememory_mobile/lib/widgets/archive_quick_explain_card.dart",
];

const PRIMARY_PAGES = [
  "app/page.tsx",
  "app/discover/page.tsx",
  "app/pricing/PricingPageClient.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
];

const DISCOURAGED = [
  /\bHypothesis\b/i,
  /\bPattern review\b/i,
  /\bInsight score\b/i,
  /\bDiscovery engine\b/i,
];

/** Standalone "Theory" as product label in user copy. */
const THEORY_LABEL = /\bTheory\b/i;

function scanFile(rel) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const pattern of DISCOURAGED) {
    if (pattern.test(src)) {
      failures.push(`${rel}: discouraged terminology`);
    }
  }
  if (THEORY_LABEL.test(src) && !rel.includes("/theories/")) {
    failures.push(`${rel}: prefer "belief" over "Theory" in user copy`);
  }
}

for (const rel of MUST_BE_CLEAN) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
  else scanFile(rel);
}

for (const rel of PRIMARY_PAGES) {
  if (fs.existsSync(path.join(ROOT, rel))) scanFile(rel);
}

const positioning = fs.readFileSync(
  path.join(ROOT, "lib/product/archive-positioning.ts"),
  "utf8",
);
if (positioning.includes("ARCHIVE_IDENTITY_ONE_LINER") && positioning.split("\n").filter((l) => l.includes("keeps track")).length > 2) {
  failures.push("archive-positioning must not duplicate competing positioning variants");
}

if (failures.length) {
  console.error("validate-archive-language failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-language passed");
