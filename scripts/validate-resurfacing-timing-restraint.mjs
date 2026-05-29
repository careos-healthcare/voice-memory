#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/revisit/resurfacing-timing.ts",
  "types/resurfacing-timing.ts",
  "lib/debug/resurfacing-timing-review.ts",
  "components/internal/ResurfacingTimingDebugPanel.tsx",
  "app/internal/resurfacing-timing/page.tsx",
  "lib/revisit/resurfacing-confidence.ts",
  "lib/refinement/callback-tuning.ts",
  "lib/refinement/revisit-experience.ts",
  "lib/retention/first-magic-moment.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Resurfacing timing validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const timing = fs.readFileSync(path.join(ROOT, "lib/revisit/resurfacing-timing.ts"), "utf8");
const memoryNote = fs.readFileSync(path.join(ROOT, "components/patterns/MemoryNote.tsx"), "utf8");
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const THRESHOLDS = [
  "TIMING_MIN_EMOTIONAL_DISTANCE_DAYS",
  "TIMING_SAME_DAY_STRONG_PHRASE_MIN",
  "TIMING_NOVELTY_COOLDOWN_HOURS",
  "TIMING_REPEATED_CALLBACK_COOLDOWN_DAYS",
  "TIMING_FRESHNESS_DECAY_DAYS",
  "TIMING_LONG_GAP_BOOST_DAYS",
  "TIMING_SILENCE_GAP_DAYS",
];

for (const name of THRESHOLDS) {
  if (!timing.includes(name)) {
    console.error(`Resurfacing timing validation failed — missing constant ${name}`);
    process.exit(1);
  }
}

const EXPORTS = [
  "assessResurfacingTiming",
  "shouldSuppressResurfacingTiming",
  "isResurfacingTimingEligible",
  "pickTimingEligibleNotes",
];

for (const name of EXPORTS) {
  if (!timing.includes(name)) {
    console.error(`Resurfacing timing validation failed — missing export ${name}`);
    process.exit(1);
  }
}

const SUPPRESS_RULES = [
  "same_day",
  "minimum_emotional_distance",
  "novelty_cooldown",
  "repeated_callback_cooldown",
  "already_processed",
  "freshness_decay",
];

for (const rule of SUPPRESS_RULES) {
  if (!timing.includes(rule)) {
    console.error(`Resurfacing timing validation failed — missing suppress rule ${rule}`);
    process.exit(1);
  }
}

const userFacingScorePatterns = [
  /timingScore/,
  /timing score/i,
  /timingClass/,
  /strong_timing/,
  /cooling_down/,
];

for (const pattern of userFacingScorePatterns) {
  if (pattern.test(memoryNote)) {
    console.error("Resurfacing timing validation failed — timing metadata exposed in MemoryNote UI.");
    process.exit(1);
  }
}

if (!packageJson.includes("validate:resurfacing-timing")) {
  console.error("Resurfacing timing validation failed — npm script not wired.");
  process.exit(1);
}

console.log("Resurfacing timing restraint validation passed.");
