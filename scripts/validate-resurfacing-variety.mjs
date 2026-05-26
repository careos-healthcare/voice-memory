#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/resurfacing/return-modes.ts",
  "lib/resurfacing/resurfacing-mode-observation.ts",
  "lib/resurfacing/resurfacing-variety-report.ts",
  "lib/resurfacing/resurfacing-frequency.ts",
  "lib/resurfacing/resurfacing-change-detection.ts",
  "lib/resurfacing/resurfacing-natural-voice.ts",
  "types/resurfacing-variety.ts",
  "app/debug/resurfacing-variety/page.tsx",
  "components/debug/ResurfacingVarietyPanel.tsx",
];

const BANNED = [
  /\btherapy\b/i,
  /\bcoach\b/i,
  /\byou should\b/i,
  /\binspirational\b/i,
  /\bhealing journey\b/i,
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const modes = fs.readFileSync(
  path.join(ROOT, "lib/resurfacing/return-modes.ts"),
  "utf8",
);
for (const token of [
  "exact_echo",
  "contradiction",
  "silence_gap",
  "escalation",
  "recurrence_observation",
  "filterCallbacksByModeDiversity",
  "getReturnModeFatiguePenalty",
  "resurfacing_mode_shown",
]) {
  if (!modes.includes(token)) {
    failures.push(`return-modes missing ${token}`);
  }
}

const tuning = fs.readFileSync(
  path.join(ROOT, "lib/refinement/callback-tuning.ts"),
  "utf8",
);
if (!tuning.includes("filterCallbacksByModeDiversity")) {
  failures.push("callback-tuning must diversify by return mode");
}

const sideEffects = fs.readFileSync(
  path.join(ROOT, "lib/refinement/presentation-side-effects.ts"),
  "utf8",
);
if (!sideEffects.includes("observeResurfacingModeShown")) {
  failures.push("presentation-side-effects must track resurfacing_mode_shown");
}

const panel = fs.readFileSync(
  path.join(ROOT, "components/debug/ResurfacingVarietyPanel.tsx"),
  "utf8",
);
for (const section of [
  "Mode distribution",
  "Repetition warnings",
  "Overused phrases",
  "cadence clustering",
  "Frequency restraint",
]) {
  if (!panel.includes(section) && !panel.toLowerCase().includes(section.toLowerCase())) {
    failures.push(`ResurfacingVarietyPanel missing ${section}`);
  }
}

for (const rel of ["lib/resurfacing/return-modes.ts", "components/debug/ResurfacingVarietyPanel.tsx"]) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const re of BANNED) {
    if (re.test(text)) failures.push(`${rel}: banned ${re}`);
  }
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:resurfacing-variety")) {
  failures.push("package.json must wire validate:resurfacing-variety");
}

if (failures.length > 0) {
  console.error("validate-resurfacing-variety failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-resurfacing-variety ok");
