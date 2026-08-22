#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "docs/INTERNAL_COMPLEXITY_REPORT.md");

const { buildInternalComplexityReport } = await import(
  "../packages/shared/lib/internal/internal-complexity-report.ts"
);
const { getInternalSurfaceRegistry } = await import(
  "../packages/shared/lib/internal/internal-surface-registry.ts"
);

const report = buildInternalComplexityReport(path.join(ROOT, "app"));
const registry = getInternalSurfaceRegistry();

const panelRows = registry
  .filter((r) => r.panelComponent)
  .map((r) => {
    const esc = (s) => String(s ?? "").replace(/\|/g, "\\|");
    return `| ${esc(r.panelComponent)} | ${r.kind} | ${esc(r.route ?? "—")} | ${r.disposition} | ${r.hasEvents ? "yes" : "no"} | ${r.hasUsageSignals ? "yes" : "no"} | ${r.drivesDecisions ? "yes" : "no"} | ${esc(r.staleReason ?? "")} |`;
  });

const md = [
  "# Internal Complexity Report",
  "",
  "Internal Complexity Reduction v1 — founder tooling vs customer product.",
  "",
  `_Generated ${report.generatedAt}_`,
  "",
  "## Summary",
  "",
  "| Metric | Value |",
  "| --- | --- |",
  `| Public routes | ${report.publicRouteCount} |`,
  `| Internal routes | ${report.internalRouteCount} |`,
  `| Internal : public ratio | ${report.internalToPublicRatio} |`,
  `| **Internal Complexity Score** | **${report.internalComplexityScore}** |`,
  `| Active KEEP panels | ${report.activePanelCount} |`,
  `| Target | < ${25} active internal panels |`,
  `| Meets target | ${report.meetsActiveTarget ? "yes" : "no"} |`,
  "",
  "## Stale panel disposition",
  "",
  `- **KEEP:** ${report.staleByDisposition.KEEP.length}`,
  `- **MERGE:** ${report.staleByDisposition.MERGE.length}`,
  `- **DELETE:** ${report.staleByDisposition.DELETE.length}`,
  "",
  "## Unused panels (no events / usage / decisions)",
  "",
  ...report.unusedPanels.slice(0, 20).map((p) => `- **${p.disposition}** ${p.label} — ${p.staleReason ?? "review"}`),
  "",
  "## Panel registry",
  "",
  "| Panel | Kind | Route | Disposition | Events | Usage | Decisions | Notes |",
  "| --- | --- | --- | --- | --- | --- | --- | --- |",
  ...panelRows,
  "",
  "## Notes",
  "",
  "- Set `FOUNDER_MODE=true` to expose `/internal/*` (still requires debug token or founder session).",
  "- Customer product routes are audited separately in `lib/product/surface-audit.ts`.",
  "",
];

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, md.join("\n"));
console.log(`Wrote ${OUT}`);
