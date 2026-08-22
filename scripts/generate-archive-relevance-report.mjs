#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "docs/ARCHIVE_RELEVANCE_REPORT.md");

const { buildArchiveRelevanceReport } = await import("../packages/shared/lib/product/archive-relevance.ts");

const report = buildArchiveRelevanceReport();

const header = [
  "# Archive Relevance Report",
  "",
  "Surface Reduction v2 — which routes stay prominent vs demoted.",
  "",
  ...report.lines.map((l) => (l.startsWith("Generated") ? `_ ${l}_` : l)),
  "",
  "| Route | Purpose | Category | Keep | Merge | Hide | Reason |",
  "| --- | --- | --- | --- | --- | --- | --- |",
];

const rows = report.rows.map((r) => {
  const esc = (s) => String(s).replace(/\|/g, "\\|").replace(/\n/g, " ");
  return `| ${esc(r.route)} | ${esc(r.purpose)} | ${r.level} | ${r.keep ? "yes" : "no"} | ${esc(r.merge ?? "—")} | ${r.hide ? "yes" : "no"} | ${esc(r.reason)} |`;
});

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, [...header, ...rows, "", ""].join("\n"));
console.log(`Wrote ${OUT} (${report.rows.length} routes)`);
