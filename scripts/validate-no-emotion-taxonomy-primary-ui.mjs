#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const primaryFiles = [
  "app/insights/page.tsx",
  "app/timeline/page.tsx",
  "app/memory/page.tsx",
  "app/journal/page.tsx",
  "components/continuity/ReturnThreadCard.tsx",
  "components/continuity/ReturnThreadsOverview.tsx",
];

const banned = [
  /Dominant mood/i,
  /Mood snapshot/i,
  /emotional trend/i,
  /IntensityTrendChart/,
  /reflection\.mood/,
  /emotionalIntensity\/10/,
  /Emotional evolution/i,
  /speaker expresses/i,
  /\bAI analysis\b/i,
  /\bEmotional analytics\b/i,
  /PatternsDetectedSection/,
  /MemoryTimelineDashboard/,
];

const failures = [];
for (const file of primaryFiles) {
  const text = fs.readFileSync(path.join(ROOT, file), "utf8");
  for (const re of banned) {
    if (re.test(text)) failures.push(`${file} matches ${re}`);
  }
}

if (failures.length > 0) {
  console.error("validate-no-emotion-taxonomy-primary-ui failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-no-emotion-taxonomy-primary-ui ok");
