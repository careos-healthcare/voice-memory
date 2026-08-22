#!/usr/bin/env node
/**
 * Design Consistency Audit & Enforcement
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

const requiredModules = [
  "packages/shared/lib/design/archive-page-grammar.ts",
  "packages/shared/lib/design/archive-typography-audit.ts",
  "packages/shared/lib/design/archive-spacing-audit.ts",
  "packages/shared/lib/design/archive-cta-map.ts",
  "packages/shared/lib/design/archive-density.ts",
  "packages/shared/lib/design/archive-visual-weight.ts",
  "packages/shared/lib/design/mobile-design-consistency-audit.ts",
  "packages/shared/lib/design/design-consistency-score.ts",
  "packages/shared/lib/design/scan-pattern-audit.ts",
  "packages/shared/lib/internal/design-consistency-file-audit.ts",
  "apps/web/components/internal/DesignConsistencyAuditPanel.tsx",
  "apps/web/components/layout/ArchiveGrammarSection.tsx",
];

for (const rel of requiredModules) mustExist(rel);

const grammar = read("packages/shared/lib/design/archive-page-grammar.ts");
for (const section of [
  "identity",
  "current_state",
  "change",
  "evidence",
  "supporting_context",
  "action",
]) {
  if (!grammar.includes(`"${section}"`)) fail(`PAGE_STRUCTURE missing ${section}`);
}

const blueprint = read("apps/web/components/layout/ArchivePageBlueprint.tsx");
if (!blueprint.includes("data-archive-grammar-section")) {
  fail("ArchivePageBlueprint must emit grammar section markers");
}

const panel = read("apps/web/components/internal/DesignConsistencyAuditPanel.tsx");
if (!panel.includes("CONSISTENT") || !panel.includes("INCONSISTENT")) {
  fail("DesignConsistencyAuditPanel must show CONSISTENT / INCONSISTENT");
}

if (!read("apps/web/components/internal/FounderTestPanel.tsx").includes("DesignConsistencyAuditPanel")) {
  fail("FounderTestPanel must mount DesignConsistencyAuditPanel");
}

const surfaces = [
  "apps/web/app/discover/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/account/page.tsx",
  "apps/web/app/archive-detail/page.tsx",
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
];

for (const page of surfaces) {
  const src = read(page);
  if (!src.includes("ArchivePageBlueprint")) {
    fail(`${page} must use ArchivePageBlueprint`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:design-consistency"]) {
  fail("package.json missing validate:design-consistency");
}

try {
  const { buildDesignConsistencyFileReport } = await import(
    path.join(ROOT, "packages/shared/lib/internal/design-consistency-file-audit.ts")
  );
  const report = buildDesignConsistencyFileReport();
  console.log(`DESIGN_CONSISTENCY_SCORE_V2=${report.score.total}`);
  console.log(
    `  typography=${report.score.typography} spacing=${report.score.spacing} hierarchy=${report.score.hierarchy} cta=${report.score.cta} visualWeight=${report.score.visualWeight} mobile=${report.score.mobile}`,
  );
  for (const scan of report.scanPatterns) {
    console.log(`  scan:${scan.surface}=${scan.verdict}`);
    if (scan.verdict === "INCONSISTENT") {
      fail(`${scan.surface}: scan pattern ${scan.notes.join("; ") || "inconsistent"}`);
    }
  }
  if (report.score.total < 95) {
    fail(`DESIGN_CONSISTENCY_SCORE_V2 ${report.score.total} below target 95`);
    for (const f of report.failures) fail(f);
  }
} catch (e) {
  fail(`design-consistency-file-audit failed: ${e.message}`);
}

const uniqueFailures = [...new Set(failures)];
if (uniqueFailures.length) {
  console.error("validate-design-consistency failed:\n");
  for (const f of uniqueFailures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-design-consistency ok");
