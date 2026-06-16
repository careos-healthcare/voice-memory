#!/usr/bin/env node
/**
 * Mobile Production Readiness v1 — writes docs/MOBILE_READINESS_REPORT.md
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const { buildMobileProductionReadinessReport } = await import(
  path.join(ROOT, "lib/mobile/mobile-production-readiness.ts")
);

const report = buildMobileProductionReadinessReport();

function pillarSection(pillar) {
  return [
    `## ${pillar.label}`,
    "",
    `**Status:** ${pillar.status}`,
    "",
    `${pillar.passing}/${pillar.total} passing — ${pillar.summary}`,
    "",
  ].join("\n");
}

const checklist = report.items
  .map(
    (item) =>
      `### ${item.label}\n\n- **Status:** ${item.status}\n- **Evidence:** ${item.requiredEvidence.join(", ")}\n${
        item.evidenceNotes.length
          ? item.evidenceNotes.map((n) => `- ${n}`).join("\n")
          : "- (no notes)"
      }\n`,
  )
  .join("\n");

const md = [
  "# Mobile readiness report",
  "",
  `Generated: ${report.generatedAt}`,
  "",
  "Overall pillars for store submission — evidence only, no manual checkboxes.",
  "",
  pillarSection(report.productReadiness),
  pillarSection(report.storeReadiness),
  pillarSection(report.distributionReadiness),
  "## Checklist",
  "",
  checklist,
  "## Summary",
  "",
  `- Passing: ${report.passingCount}`,
  `- Failing: ${report.failingCount}`,
  `- Unknown: ${report.unknownCount}`,
  "",
  "Add proof: `mobile/evidence/<id>.json` — see `mobile/evidence/README.md`.",
  "",
  ...report.lines.map((line) => (line ? `- ${line}` : "")),
  "",
].join("\n");

const outPath = path.join(ROOT, "docs/MOBILE_READINESS_REPORT.md");
fs.writeFileSync(outPath, md, "utf8");
console.log(`Wrote ${outPath}`);
console.log(
  `Readiness: ${report.passingCount} passing, ${report.failingCount} failing, ${report.unknownCount} unknown`,
);
