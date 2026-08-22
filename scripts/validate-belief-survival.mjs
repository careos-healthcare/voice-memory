#!/usr/bin/env node
/**
 * Belief Survival System — durability metrics on archive, dossier, and discover.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "packages/shared/types/belief-survival.ts",
  "packages/shared/lib/archive/belief-survival.ts",
  "apps/web/components/archive/BeliefSurvivalCard.tsx",
];

for (const rel of required) mustExist(rel);

const lib = read("packages/shared/lib/archive/belief-survival.ts");
for (const phrase of [
  "BELIEF_SURVIVAL_TITLE",
  "buildBeliefSurvivalView",
  "beliefSurvivedChallengesLine",
  "beliefEvolvingDaysLine",
  "This belief has survived",
  "This belief has been evolving for",
  "daysAlive",
  "reflectionsSupporting",
  "contradictionsSurvived",
  "confidenceMovementHistory",
  "firstAppearedDate",
]) {
  if (!lib.includes(phrase)) fail(`belief-survival missing: ${phrase}`);
}

const card = read("apps/web/components/archive/BeliefSurvivalCard.tsx");
for (const phrase of [
  'data-testid="belief-survival-card"',
  "buildBeliefSurvivalView",
  "Days alive",
  "Reflections supporting",
  "Contradictions survived",
  "Confidence movement history",
  "First appeared",
]) {
  if (!card.includes(phrase)) fail(`BeliefSurvivalCard missing: ${phrase}`);
}

const surfaces = [
  ["apps/web/components/archive/BeliefDossier.tsx", "Belief Dossier"],
  ["apps/web/app/discover/page.tsx", "Discover"],
];

for (const [file, label] of surfaces) {
  const src = read(file);
  if (!src.includes("BeliefSurvivalCard")) {
    fail(`${label} (${file}) must render BeliefSurvivalCard`);
  }
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:belief-survival"]) {
  fail("package.json missing validate:belief-survival");
}

if (failures.length) {
  console.error("validate-belief-survival failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-belief-survival ok");
