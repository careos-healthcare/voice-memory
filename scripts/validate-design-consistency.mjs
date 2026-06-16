#!/usr/bin/env node
/**
 * Archive Experience System v1 — design consistency validator.
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
  "lib/design/archive-typography.ts",
  "lib/design/archive-spacing.ts",
  "lib/design/archive-visual-gravity.ts",
  "lib/design/archive-experience-language.ts",
  "components/layout/ArchivePageBlueprint.tsx",
  "components/layout/ArchiveActionArea.tsx",
  "components/archive/ArchiveCard.tsx",
  "lib/internal/archive-experience-report.ts",
  "apps/voicememory_mobile/lib/widgets/archive_mobile_page_template.dart",
  "apps/voicememory_mobile/lib/design/archive_mobile_spacing.dart",
  "apps/voicememory_mobile/lib/design/archive_mobile_typography.dart",
];

for (const rel of required) mustExist(rel);

const blueprintSurfaces = [
  "app/discover/page.tsx",
  "app/blind-spots/page.tsx",
  "app/updates/page.tsx",
  "app/memory/page.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
];

for (const page of blueprintSurfaces) {
  const src = read(page);
  if (!src.includes("ArchivePageBlueprint")) {
    fail(`${page} must use ArchivePageBlueprint`);
  }
  if (!src.includes('data-testid="archive-page-blueprint"') && !src.includes("ArchivePageBlueprint")) {
    // blueprint renders testid internally
  }
  if (/\btext-(2xl|3xl|4xl)\b/.test(src)) {
    fail(`${page} must not use page-level text-2xl/3xl/4xl — use ARCHIVE_TYPO`);
  }
  const arbitrary = src.match(/\b[mp][trblxy]?-\[[^\]]+\]/g);
  if (arbitrary?.length) {
    fail(`${page} has arbitrary spacing: ${arbitrary.slice(0, 3).join(", ")}`);
  }
}

for (const page of ["app/discover/page.tsx", "app/blind-spots/page.tsx", "app/updates/page.tsx"]) {
  if (!read(page).includes("ArchiveActionArea")) {
    fail(`${page} must use ArchiveActionArea`);
  }
}

if (!read("lib/product/archive-product-copy.ts").includes("What changed since your last visit?")) {
  fail("Discover must headline archive change log");
}

const blind = read("lib/blind-spots/blind-spot-copy.ts");
if (!blind.includes("one reason your archive currently believes")) {
  fail("Blind spots lead must frame archive evidence");
}

const blueprint = read("components/layout/ArchivePageBlueprint.tsx");
if (!blueprint.includes("data-archive-section")) {
  fail("ArchivePageBlueprint must tag sections for visual gravity");
}
if (!blueprint.includes("ARCHIVE_BLUEPRINT_SECTION_ORDER")) {
  fail("ArchivePageBlueprint must reference ARCHIVE_BLUEPRINT_SECTION_ORDER");
}

const gravity = read("lib/design/archive-visual-gravity.ts");
if (!gravity.includes("ARCHIVE_GRAVITY_ORDER")) {
  fail("archive-visual-gravity must define weight order");
}

const mobileShell = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
const mobileDiscover = read("apps/voicememory_mobile/lib/screens/discover_screen.dart");
if (!mobileShell.includes("ArchiveMobilePageTemplate")) {
  fail("archive_belief_screen must use ArchiveMobilePageTemplate");
}
if (!mobileDiscover.includes("ArchiveMobilePageTemplate")) {
  fail("discover_screen must use ArchiveMobilePageTemplate");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:design-consistency"]) {
  fail("package.json missing validate:design-consistency");
}

let designConsistencyScore = 0;
try {
  const { buildArchiveExperienceReport } = await import(
    path.join(ROOT, "lib/internal/archive-experience-report.ts")
  );
  const report = buildArchiveExperienceReport();
  designConsistencyScore = report.designConsistencyScore;
  console.log(`DESIGN_CONSISTENCY_SCORE=${designConsistencyScore}`);
  console.log(
    `  typography=${report.typographyScore} spacing=${report.spacingScore} cta=${report.ctaScore} hierarchy=${report.hierarchyScore} language=${report.languageScore} consistency=${report.consistencyScore}`,
  );
  if (designConsistencyScore < 95) {
    fail(`DESIGN_CONSISTENCY_SCORE ${designConsistencyScore} below target 95`);
  }
} catch (e) {
  fail(`archive-experience-report failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-design-consistency failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-design-consistency ok");
