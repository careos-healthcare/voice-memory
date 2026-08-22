#!/usr/bin/env node
/**
 * Detect duplicate archive/theory/reflection/insight surfaces — recommendations only.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const DUPLICATE_GROUPS = [
  {
    id: "archive_surfaces",
    label: "Archive read surfaces",
    patterns: [
      "apps/web/app/archive-belief/",
      "apps/web/components/archive/EvidenceArchiveHome",
      "apps/web/components/archive/ArchiveBeliefCard",
      "apps/web/components/archive/ArchiveCommandCenter",
      "ArchiveValueBanner",
    ],
    recommendation: "KEEP command center + archive-belief; MERGE card into home; HIDE redundant banners on archive-belief",
  },
  {
    id: "theory_surfaces",
    label: "Theory / belief surfaces",
    patterns: [
      "apps/web/app/theories/",
      "apps/web/components/theories/TheoriesView",
      "apps/web/components/discover/TheoryChangeFeed",
      "BeliefDossier",
    ],
    recommendation: "KEEP dossier on archive + discover feed; HIDE theories list behind Account > More",
  },
  {
    id: "reflection_surfaces",
    label: "Reflection surfaces",
    patterns: [
      "apps/web/app/memory/",
      "apps/web/app/journal/",
      "apps/web/components/memory/",
    ],
    recommendation: "KEEP Reflection Log (/memory); HIDE journal behind Account > More",
  },
  {
    id: "insight_surfaces",
    label: "Insight / blind spot surfaces",
    patterns: [
      "apps/web/app/blind-spots/",
      "apps/web/app/insights/",
      "BlindSpotAcceleration",
      "InsightOutcome",
    ],
    recommendation: "KEEP Archive Insight (/blind-spots); HIDE legacy /insights behind More",
  },
];

function walkTsFiles(dir, base = "") {
  const out = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name.startsWith(".") || ent.name === "node_modules") continue;
    const rel = base ? `${base}/${ent.name}` : ent.name;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (["node_modules", ".next", ".git", "coverage"].includes(ent.name)) continue;
      out.push(...walkTsFiles(full, rel));
    } else if (/\.(tsx?|mjs)$/.test(ent.name)) {
      out.push(rel);
    }
  }
  return out;
}

const files = walkTsFiles(ROOT);
const report = [];

for (const group of DUPLICATE_GROUPS) {
  const hits = [];
  for (const file of files) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8");
    for (const pattern of group.patterns) {
      if (src.includes(pattern) || file.includes(pattern.replace("apps/web/app/", "").replace("apps/web/components/", ""))) {
        hits.push({ file, pattern });
      }
    }
  }
  const uniqueFiles = [...new Set(hits.map((h) => h.file))];
  report.push({
    ...group,
    fileCount: uniqueFiles.length,
    files: uniqueFiles.slice(0, 25),
    verdict: uniqueFiles.length <= 3 ? "KEEP" : uniqueFiles.length <= 8 ? "MERGE" : "HIDE",
  });
}

const outPath = path.join(ROOT, "docs/SURFACE_COMPLEXITY_REPORT.md");
const lines = [
  "# Surface complexity report",
  "",
  `Generated: ${new Date().toISOString()}`,
  "",
  "Automated recommendations only — no routes or engines removed.",
  "",
];

for (const row of report) {
  lines.push(`## ${row.label}`, "", `Verdict: **${row.verdict}**`, "", row.recommendation, "", `Files (${row.fileCount}):`, "");
  for (const f of row.files) lines.push(`- ${f}`);
  if (row.fileCount > row.files.length) lines.push(`- … and ${row.fileCount - row.files.length} more`);
  lines.push("");
}

fs.writeFileSync(outPath, lines.join("\n"), "utf8");
console.log(`Wrote ${outPath}`);
for (const row of report) {
  console.log(`  ${row.label}: ${row.verdict} (${row.fileCount} files)`);
}
