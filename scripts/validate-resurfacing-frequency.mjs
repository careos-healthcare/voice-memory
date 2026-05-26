#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/resurfacing/resurfacing-frequency.ts",
  "lib/resurfacing/resurfacing-change-detection.ts",
  "lib/resurfacing/resurfacing-specificity-gate.ts",
  "lib/resurfacing/resurfacing-natural-voice.ts",
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const frequency = fs.readFileSync(
  path.join(ROOT, "lib/resurfacing/resurfacing-frequency.ts"),
  "utf8",
);
for (const fn of [
  "shouldReduceResurfacingFrequency",
  "shouldSuppressSimilarResurfacing",
  "shouldCooldownResurfacing",
  "shouldPreferMicFirstWithoutContinuityStack",
  "capHomepageResurfacingPresentation",
]) {
  if (!frequency.includes(fn)) {
    failures.push(`resurfacing-frequency must export ${fn}`);
  }
}

const tuning = fs.readFileSync(
  path.join(ROOT, "lib/refinement/callback-tuning.ts"),
  "utf8",
);
for (const token of [
  "shouldSuppressResurfacingByFrequency",
  "hasDetectableChange",
  "passesResurfacingSpecificityGate",
  "naturalizeResurfacingNote",
]) {
  if (!tuning.includes(token)) {
    failures.push(`callback-tuning must use ${token}`);
  }
}

const quiet = fs.readFileSync(
  path.join(ROOT, "lib/refinement/quiet-presentation.ts"),
  "utf8",
);
if (!quiet.includes("capHomepageResurfacingPresentation")) {
  failures.push("quiet-presentation must cap homepage resurfacing");
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:resurfacing-frequency")) {
  failures.push("package.json must wire validate:resurfacing-frequency");
}

if (failures.length > 0) {
  console.error("validate-resurfacing-frequency failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-resurfacing-frequency ok");
