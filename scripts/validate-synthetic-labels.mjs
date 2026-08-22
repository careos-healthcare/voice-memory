#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const human = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/human-continuity-ui.ts"),
  "utf8",
);
if (!human.includes("sanitizeUserFacingObservation") || !human.includes("entryContinuitySnippet")) {
  failures.push("human-continuity-ui module incomplete");
}

const bannedInProductUi = [
  { file: "apps/web/app/journal/page.tsx", patterns: [/reflection\.mood/, /emotionalIntensity\/10/, /<Badge[^>]*>\s*\{entry\.reflection\.mood/] },
  { file: "apps/web/components/memory/MemoryContinuitySection.tsx", patterns: [/reflection\.mood/, /REASON_LABELS.*mood/] },
  { file: "apps/web/components/insights/MemoryTimelineDashboard.tsx", patterns: [/Dominant mood/, /IntensityTrendChart/, /dominantMoods\.map/] },
  { file: "apps/web/components/InsightCard.tsx", patterns: [/Mood snapshot/, /reflection\.mood/] },
  {
    file: "apps/web/components/HabitLoopCard.tsx",
    patterns: [/Dominant mood/, /Avg intensity/, /avgIntensity\/10/, /Emotional intensity/],
  },
];

for (const { file, patterns } of bannedInProductUi) {
  const text = fs.readFileSync(path.join(ROOT, file), "utf8");
  for (const re of patterns) {
    if (re.test(text)) failures.push(`${file} must not match ${re}`);
  }
}

const insightDefaults = fs.readFileSync(
  path.join(ROOT, "apps/web/components/InsightCard.tsx"),
  "utf8",
);
if (!insightDefaults.includes("calmMode = true")) {
  failures.push("InsightCard must default to calm, mood-free presentation");
}

const analyze = fs.readFileSync(path.join(ROOT, "apps/api/app/api/analyze/route.ts"), "utf8");
if (!analyze.includes("speaker expresses")) {
  failures.push("analyze route must ban speaker-expresses phrasing");
}

if (failures.length > 0) {
  console.error("validate-synthetic-labels failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-synthetic-labels ok");
