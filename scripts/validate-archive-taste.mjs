#!/usr/bin/env node
/**
 * Archive Taste & Restraint Pass v1
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
  "packages/shared/lib/design/archive-copy-restraint.ts",
  "packages/shared/lib/design/archive-success-copy.ts",
  "packages/shared/lib/design/archive-empty-state-audit.ts",
  "packages/shared/lib/design/archive-empty-state-copy.ts",
  "packages/shared/lib/design/archive-icon-registry.ts",
  "packages/shared/lib/design/archive-motion-restraint.ts",
  "packages/shared/lib/design/archive-taste-score.ts",
  "packages/shared/lib/internal/archive-taste-file-audit.ts",
  "packages/shared/lib/onboarding/onboarding-confidence-check.ts",
  "apps/web/components/onboarding/OnboardingConfidenceCheck.tsx",
];

for (const rel of required) mustExist(rel);

const restraint = read("packages/shared/lib/design/archive-copy-restraint.ts");
for (const surface of ["archive", "changes", "detail", "account"]) {
  if (!restraint.includes(`"${surface}"`)) fail(`archive-copy-restraint missing ${surface}`);
}

const success = read("packages/shared/lib/design/archive-success-copy.ts");
if (!success.includes("Archive updated.")) fail("archive-success-copy must define Archive updated.");
for (const banned of ["Success!", "Reflection processed"]) {
  if (read("packages/shared/lib/archive/reflection-impact-receipt.ts").includes(banned)) {
    fail(`reflection-impact-receipt must not use: ${banned}`);
  }
}

const emptyAudit = read("packages/shared/lib/design/archive-empty-state-audit.ts");
if (!emptyAudit.includes("ARCHIVE_EMPTY_STATE_REGISTRY")) {
  fail("archive-empty-state-audit must export empty state registry");
}

const icons = read("packages/shared/lib/design/archive-icon-registry.ts");
if (!icons.includes("ARCHIVE_ICON_REGISTRY")) fail("missing ARCHIVE_ICON_REGISTRY");

const onboarding = read("packages/shared/lib/onboarding/onboarding-confidence-check.ts");
if (!onboarding.includes("tracks_archive_belief")) {
  fail("onboarding-confidence must classify tracks_archive_belief");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-taste"]) {
  fail("package.json missing validate:archive-taste");
}

try {
  const { buildArchiveTasteFileReport } = await import(
    path.join(ROOT, "packages/shared/lib/internal/archive-taste-file-audit.ts")
  );
  const report = buildArchiveTasteFileReport();
  console.log(`ARCHIVE_TASTE_SCORE=${report.score.total}`);
  console.log(
    `  copy=${report.score.copyDensity} animation=${report.score.animationDensity} empty=${report.score.emptyStateQuality} cta=${report.score.ctaCompetition} spacing=${report.score.spacingConsistency}`,
  );
  if (report.score.total < 90) {
    fail(`ARCHIVE_TASTE_SCORE ${report.score.total} below target 90`);
    for (const f of report.failures) fail(f);
  }
} catch (e) {
  fail(`archive-taste-file-audit failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-archive-taste failed:\n");
  for (const f of [...new Set(failures)]) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-taste ok");
