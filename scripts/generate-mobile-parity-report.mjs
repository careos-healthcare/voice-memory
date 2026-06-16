#!/usr/bin/env node
/**
 * Mobile First-Class Platform Validation v1 — writes docs/MOBILE_PARITY_REPORT.md
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const { buildMobileParityReport, formatParityReportMarkdown } = await import(
  path.join(ROOT, "lib/mobile/mobile-parity-report.ts")
);

const report = buildMobileParityReport();
const md = formatParityReportMarkdown(report);
const outPath = path.join(ROOT, "docs/MOBILE_PARITY_REPORT.md");
fs.writeFileSync(outPath, md, "utf8");
console.log(`Wrote ${outPath}`);
console.log(
  `Parity: ${report.completeCount} complete, ${report.partialCount} partial, ${report.missingCount} missing`,
);
