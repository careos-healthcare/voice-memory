#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.resolve(ROOT, "..", "spp20", "debug_surface_inventory.md");

const KEPT = fs.existsSync(path.join(ROOT, "app/internal"))
  ? fs
      .readdirSync(path.join(ROOT, "app/internal"), { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .sort()
  : [];

const REMOVED_SAMPLE = [
  "resurfacing-metrics",
  "retention-readout",
  "callbacks",
  "moat",
  "production-readiness",
  "validation-ops",
  "stress",
  "changes",
  "incidents",
  "emotional-recognition-qa",
  "pilot-review",
  "user-review",
];

const lines = [
  "# ArchiveMe — debug surface inventory",
  "",
  `**Generated:** ${new Date().toISOString()}`,
  "",
  "## Summary",
  "",
  "| Metric | Count |",
  "|--------|-------|",
  `| Active /internal routes | ${KEPT.length} |`,
  "| Retired /debug/* | all → 404 |",
  "| Removed duplicate/dead routes | 37 |",
  "",
  "## Tier model",
  "",
  "| Tier | Paths | Production |",
  "|------|-------|------------|",
  "| 1 Dev only | `/demo` | 404 unless NODE_ENV=development |",
  "| 2 Founder internal | `/internal/*`, `/launch` | Token + VOICEMEMORY_ENABLE_INTERNAL + layout auth |",
  "| 3 Safe diagnostics | `/api/health` | Public minimal JSON |",
  "",
  "## Active /internal routes",
  "",
  "| Path | Purpose | Auth | Risk | Recommendation |",
  "|------|---------|------|------|----------------|",
];

for (const slug of KEPT) {
  lines.push(
    `| /internal/${slug} | Founder QA panel | Token + founder session (RSC) | Medium | keep |`,
  );
}

lines.push("", "## Retired /debug/*", "", "All `/debug/*` return **404** permanently.", "", "## Removed routes (sample)", "", "| Former path | Recommendation |", "|-------------|----------------|");

for (const slug of REMOVED_SAMPLE) {
  lines.push(`| /debug/${slug} | delete |`);
}

lines.push(
  "",
  "## API",
  "",
  "| Path | Tier | Notes |",
  "|------|------|-------|",
  "| /api/health | 3 | Production-safe |",
  "| /api/internal/auth-env | 2 | Env probe, no secrets |",
  "| /api/metrics/resurfacing | 2 | Founder session only |",
  "| /api/debug/* | — | **removed** |",
  "",
);

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, lines.join("\n"));
console.log(`Wrote ${OUT} (${KEPT.length} routes)`);
