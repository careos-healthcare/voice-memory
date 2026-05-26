#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/revisit/resurfacing-confidence.ts",
  "types/resurfacing-confidence.ts",
  "lib/debug/resurfacing-confidence-review.ts",
  "components/debug/ResurfacingConfidenceDebugPanel.tsx",
  "app/debug/resurfacing-confidence/page.tsx",
  "lib/revisit/resurfacing-copy.ts",
  "lib/refinement/quiet-presentation.ts",
  "lib/refinement/revisit-experience.ts",
  "lib/revisit/revisit-quality.ts",
  "lib/refinement/callback-tuning.ts",
  "lib/retention/first-magic-moment.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Resurfacing confidence validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const confidence = fs.readFileSync(
  path.join(ROOT, "lib/revisit/resurfacing-confidence.ts"),
  "utf8",
);
const copy = fs.readFileSync(path.join(ROOT, "lib/revisit/resurfacing-copy.ts"), "utf8");
const memoryNote = fs.readFileSync(path.join(ROOT, "types/memory-note.ts"), "utf8");
const memoryNoteComponent = fs.readFileSync(
  path.join(ROOT, "components/patterns/MemoryNote.tsx"),
  "utf8",
);
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const THRESHOLDS = [
  "CONFIDENCE_SUPPRESS_MAX",
  "CONFIDENCE_PLAUSIBLE_MIN",
  "CONFIDENCE_STRONG_MIN",
  "CONFIDENCE_MAGIC_MIN",
];

for (const name of THRESHOLDS) {
  if (!confidence.includes(name)) {
    console.error(`Resurfacing confidence validation failed — missing threshold ${name}`);
    process.exit(1);
  }
}

if (!confidence.includes("assessResurfacingConfidence") || !confidence.includes("shouldSuppressResurfacingConfidence")) {
  console.error("Resurfacing confidence validation failed — missing core scoring exports.");
  process.exit(1);
}

if (!confidence.includes("mood_only_match") || !confidence.includes("no_why_now")) {
  console.error("Resurfacing confidence validation failed — missing weak/generic suppress rules.");
  process.exit(1);
}

const evidenceLines = [
  "You used similar words",
  "This concern showed up again after a quiet stretch.",
  "You mentioned",
  "Your tone changed around the same topic.",
  "This came back on the same kind of day.",
];

for (const line of evidenceLines) {
  if (!copy.includes(line)) {
    console.error(`Resurfacing confidence validation failed — missing evidence copy: ${line}`);
    process.exit(1);
  }
}

if (!copy.includes("pickResurfacingEvidenceReason") || !copy.includes("RESURFACING_WHY_NOW_COPY")) {
  console.error("Resurfacing confidence validation failed — missing evidence reason picker.");
  process.exit(1);
}

if (!memoryNote.includes("evidenceReason")) {
  console.error("Resurfacing confidence validation failed — MemoryNote missing evidenceReason.");
  process.exit(1);
}

const userFacingScorePatterns = [
  /totalConfidence/,
  /confidence score/i,
  /your score/i,
  /\b\d{1,3}% confidence\b/i,
];

for (const pattern of userFacingScorePatterns) {
  if (pattern.test(memoryNoteComponent)) {
    console.error(
      "Resurfacing confidence validation failed — user-facing numeric confidence in MemoryNote UI.",
    );
    process.exit(1);
  }
}

if (!packageJson.includes("validate:resurfacing-confidence")) {
  console.error("Resurfacing confidence validation failed — npm script not wired.");
  process.exit(1);
}

console.log("Resurfacing confidence restraint validation passed.");
