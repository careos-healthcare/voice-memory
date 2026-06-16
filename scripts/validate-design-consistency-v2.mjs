#!/usr/bin/env node
/**
 * Design Consistency Audit & Enforcement v2
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
  "lib/design/archive-page-grammar.ts",
  "lib/design/archive-typography-audit.ts",
  "lib/design/archive-spacing-audit.ts",
  "lib/design/archive-cta-map.ts",
  "lib/design/archive-density.ts",
  "lib/design/archive-visual-weight.ts",
  "lib/design/mobile-design-consistency-audit.ts",
  "lib/design/design-consistency-score.ts",
  "lib/design/scan-pattern-audit.ts",
  "lib/internal/design-consistency-file-audit.ts",
  "components/internal/DesignConsistencyAuditPanel.tsx",
  "components/layout/ArchiveGrammarSection.tsx",
];

for (const rel of requiredModules) mustExist(rel);

const grammar = read("lib/design/archive-page-grammar.ts");
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

const blueprint = read("components/layout/ArchivePageBlueprint.tsx");
if (!blueprint.includes("data-archive-grammar-section")) {
  fail("ArchivePageBlueprint must emit grammar section markers");
}

const panel = read("components/internal/DesignConsistencyAuditPanel.tsx");
if (!panel.includes("CONSISTENT") || !panel.includes("INCONSISTENT")) {
  fail("DesignConsistencyAuditPanel must show CONSISTENT / INCONSISTENT");
}

if (!read("components/internal/FounderTestPanel.tsx").includes("DesignConsistencyAuditPanel")) {
  fail("FounderTestPanel must mount DesignConsistencyAuditPanel");
}

const surfaces = [
  "app/discover/page.tsx",
  "app/memory/page.tsx",
  "app/account/page.tsx",
  "app/archive-detail/page.tsx",
  "components/archive/EvidenceArchiveHome.tsx",
];

for (const page of surfaces) {
  const src = read(page);
  if (!src.includes("ArchivePageBlueprint")) {
    fail(`${page} must use ArchivePageBlueprint`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:design-consistency-v2"]) {
  fail("package.json missing validate:design-consistency-v2");
}

try {
  const { buildDesignConsistencyFileReport } = await import(
    path.join(ROOT, "lib/internal/design-consistency-file-audit.ts")
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
  console.error("validate-design-consistency-v2 failed:\n");
  for (const f of uniqueFailures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-design-consistency-v2 ok");
