#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/revisit/callback-learning.ts",
  "types/callback-learning.ts",
  "lib/debug/callback-learning-review.ts",
  "components/internal/CallbackLearningDebugPanel.tsx",
  "app/internal/callback-learning/page.tsx",
  "lib/revisit/resurfacing-confidence.ts",
  "lib/refinement/callback-tuning.ts",
  "lib/retention/return-triggers.ts",
  "lib/retention/first-magic-moment.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Callback learning validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const learning = fs.readFileSync(path.join(ROOT, "lib/revisit/callback-learning.ts"), "utf8");
const memoryNote = fs.readFileSync(path.join(ROOT, "components/patterns/MemoryNote.tsx"), "utf8");
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const CAPS = [
  "LEARNING_WEIGHT_MIN",
  "LEARNING_WEIGHT_MAX",
  "LEARNING_RANK_CAP",
  "LEARNING_INTERACTION_CAP",
];

for (const name of CAPS) {
  if (!learning.includes(name)) {
    console.error(`Callback learning validation failed — missing cap ${name}`);
    process.exit(1);
  }
}

const EVENTS = [
  "callback_shown",
  "callback_ignored",
  "callback_opened",
  "callback_reread",
  "callback_saved",
  "callback_shared",
  "callback_dismissed",
  "reflection_after_callback",
  "return_after_callback",
];

for (const event of EVENTS) {
  if (!learning.includes(event)) {
    console.error(`Callback learning validation failed — missing event ${event}`);
    process.exit(1);
  }
}

const KINDS = [
  "repeated_phrase",
  "repeated_concern",
  "mood_shift",
  "named_person_topic",
  "time_gap",
  "audio_photo_anchored",
];

for (const kind of KINDS) {
  if (!learning.includes(kind)) {
    console.error(`Callback learning validation failed — missing kind ${kind}`);
    process.exit(1);
  }
}

if (!learning.includes("classifyCallbackLearningKinds") || !learning.includes("applyCallbackLearningRankAdjustment")) {
  console.error("Callback learning validation failed — missing core exports.");
  process.exit(1);
}

const userFacingPatterns = [/learning weight/i, /rankAdjustment/, /interactionBoost/, /callback learning score/i];
for (const pattern of userFacingPatterns) {
  if (pattern.test(memoryNote)) {
    console.error("Callback learning validation failed — learning metadata exposed in MemoryNote UI.");
    process.exit(1);
  }
}

if (!packageJson.includes("validate:callback-learning")) {
  console.error("Callback learning validation failed — npm script not wired.");
  process.exit(1);
}

console.log("Callback learning restraint validation passed.");
