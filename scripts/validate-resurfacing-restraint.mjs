#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/revisit/resurfacing-copy.ts",
  "lib/memory/resurfacing.ts",
  "lib/memory/revisitation.ts",
  "lib/revisit/revisit-quality.ts",
  "lib/refinement/callback-tuning.ts",
  "lib/refinement/reopen-payoff.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Resurfacing validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const resurfacingCopy = fs.readFileSync(
  path.join(ROOT, "lib/revisit/resurfacing-copy.ts"),
  "utf8",
);
const resurfacing = fs.readFileSync(path.join(ROOT, "lib/memory/resurfacing.ts"), "utf8");
const revisitation = fs.readFileSync(path.join(ROOT, "lib/memory/revisitation.ts"), "utf8");
const revisitQuality = fs.readFileSync(
  path.join(ROOT, "lib/revisit/revisit-quality.ts"),
  "utf8",
);
const callbackTuning = fs.readFileSync(
  path.join(ROOT, "lib/refinement/callback-tuning.ts"),
  "utf8",
);
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const requiredCopy = [
  "You said something similar",
  "This came back in different words.",
  "The same concern showed up again, but softer.",
  "This used to sound heavier.",
  "You named this before, then left it alone.",
];

for (const line of requiredCopy) {
  if (!resurfacingCopy.includes(line)) {
    console.error(`Resurfacing validation failed — missing copy pattern: ${line}`);
    process.exit(1);
  }
}

if (!resurfacingCopy.includes("isBlockedResurfacingCopy") || !resurfacingCopy.includes("ADVICE_RESURFACING_RE")) {
  console.error("Resurfacing validation failed — missing blocked copy guards.");
  process.exit(1);
}

if (!resurfacing.includes("pickResurfacingHeadline") || !resurfacing.includes("isBlockedResurfacingCopy")) {
  console.error("Resurfacing validation failed — resurfacing.ts must use quality copy module.");
  process.exit(1);
}

if (resurfacing.includes("You came back to the same place")) {
  console.error("Resurfacing validation failed — generic same-place copy still present.");
  process.exit(1);
}

if (!revisitation.includes("pickResurfacingHeadline")) {
  console.error("Resurfacing validation failed — revisitation.ts must use pickResurfacingHeadline.");
  process.exit(1);
}

if (!revisitQuality.includes("isBlockedResurfacingCopy") || !revisitQuality.includes("scoreRepeatedPhrase")) {
  console.error("Resurfacing validation failed — revisit-quality must block generic copy and score phrases.");
  process.exit(1);
}

if (!callbackTuning.includes("isBlockedResurfacingCopy")) {
  console.error("Resurfacing validation failed — callback-tuning must reject blocked resurfacing copy.");
  process.exit(1);
}

if (!packageJson.includes("validate:resurfacing")) {
  console.error("Resurfacing validation failed — package.json missing validate:resurfacing script.");
  process.exit(1);
}

console.log("Resurfacing quality validation passed.");
