#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/resurfacing/resurfacing-fatigue.ts",
  "lib/resurfacing/behavioral-ranking.ts",
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const fatigue = fs.readFileSync(
  path.join(ROOT, "lib/resurfacing/resurfacing-fatigue.ts"),
  "utf8",
);

for (const fn of [
  "recordResurfacingIgnored",
  "recordResurfacingOpenedWithoutReflection",
  "recordResurfacingDismissed",
  "shouldSuppressResurfacingNote",
  "getResurfacingFatiguePenalty",
]) {
  if (!fatigue.includes(fn)) {
    failures.push(`resurfacing-fatigue must export ${fn}`);
  }
}

const ranking = fs.readFileSync(
  path.join(ROOT, "lib/resurfacing/behavioral-ranking.ts"),
  "utf8",
);
if (!ranking.includes("applyBehavioralRankingBoost")) {
  failures.push("behavioral-ranking must export applyBehavioralRankingBoost");
}

const tuning = fs.readFileSync(
  path.join(ROOT, "lib/refinement/callback-tuning.ts"),
  "utf8",
);
if (!tuning.includes("shouldSuppressResurfacingNote")) {
  failures.push("callback-tuning must apply resurfacing fatigue suppression");
}

if (failures.length > 0) {
  console.error("validate-resurfacing-fatigue failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-resurfacing-fatigue ok");
