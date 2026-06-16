#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
  clear: () => storage.clear(),
  get length() {
    return storage.size;
  },
  key: (i) => [...storage.keys()][i] ?? null,
};

function entry(id, day, transcript, reflection = {}) {
  const date = new Date(`2026-02-${String(day).padStart(2, "0")}T12:00:00.000Z`);
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work", "money"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      ...reflection,
    },
    durationSeconds: 40,
  };
}

const entries = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 25, "I should have spoken up but I keep waiting to quit."),
  entry("e7", 28, "It went better than I feared — I finally spoke up."),
];

const { buildSelfRecognitionIngredientsReport } = await import(
  "../lib/insights/self-recognition-ingredients.ts"
);
const {
  clearBlindSpotFeedbackForEval,
  saveBlindSpotReaction,
} = await import("../lib/blind-spots/blind-spot-feedback.ts");
const {
  clearTheoryFeedbackForEval,
  saveTheoryFeedback,
} = await import("../lib/theories/theory-feedback.ts");
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");
const { buildTheoryTrackerReport } = await import("../lib/theories/theory-generation.ts");

clearBlindSpotFeedbackForEval();
clearTheoryFeedbackForEval();
clearTheorySnapshotsForEval();

const theories = buildTheoryTrackerReport(entries, { persistSnapshots: false }).all;
assert.ok(theories.length >= 1, "need theories from fixture");
const theory = theories[0];

saveBlindSpotReaction({
  reviewId: "blind-spot:avoidance_signal:fixture",
  reaction: "uncomfortably_accurate",
  headline: "One possible pattern: circling",
  evidenceStrength: "high",
  estimatedImpactScore: 78,
  reflectionCount: 6,
  archiveAgeDays: 21,
});

saveBlindSpotReaction({
  reviewId: "blind-spot:avoidance_signal:fixture",
  reaction: "completely_wrong",
  headline: "One possible pattern: circling",
  evidenceStrength: "low",
  estimatedImpactScore: 22,
  reflectionCount: 4,
  archiveAgeDays: 10,
});

saveTheoryFeedback({
  theoryId: theory.id,
  reaction: "surprising",
  statement: theory.statement,
  source: theory.source,
  confidence: theory.confidence,
});

saveTheoryFeedback({
  theoryId: theory.id,
  reaction: "not_true",
  statement: theory.statement,
  source: theory.source,
  confidence: theory.confidence,
});

const report = buildSelfRecognitionIngredientsReport(entries);

assert.ok(report.strongReactionCount >= 2, "expected strong reactions");
assert.ok(report.weakReactionCount >= 2, "expected weak reactions");
assert.ok(report.strongestInsights.length >= 1);
assert.ok(report.weakestInsights.length >= 1);
assert.ok(report.ingredientComparisons.length >= 8);
assert.ok(report.commonStrongIngredients.length >= 1);
assert.ok(report.commonWeakIngredients.length >= 1);
assert.ok(report.bySurface.some((r) => r.surface === "blind_spot"));
assert.ok(report.bySurface.some((r) => r.surface === "theory"));

const firstStrong = report.strongestInsights[0];
assert.ok(firstStrong.ingredients.evidenceQuoteCount >= 0);
assert.ok(typeof firstStrong.ingredients.timeSpanDays === "number");
assert.ok(typeof firstStrong.ingredients.lifeAreaCount === "number");
assert.ok(typeof firstStrong.ingredients.contradictionCount === "number");
assert.ok(typeof firstStrong.ingredients.predictionFailureCount === "number");
assert.ok(typeof firstStrong.ingredients.costEvidenceCount === "number");
assert.ok(typeof firstStrong.ingredients.rootBeliefPresent === "number");
assert.ok(typeof firstStrong.ingredients.specificityScore === "number");
assert.ok(typeof firstStrong.ingredients.confidenceScore === "number");
assert.ok(report.accuracyCorrelationLines.length >= 1);
assert.ok(typeof firstStrong.ingredients.evidenceStrengthScore === "number");
assert.ok(firstStrong.ingredients.evidenceStrength.length > 0);

const comparison = report.ingredientComparisons.find(
  (r) => r.key === "confidenceScore",
);
assert.ok(comparison);
assert.ok(
  comparison.strongAverage === null ||
    comparison.weakAverage === null ||
    comparison.strongAverage >= comparison.weakAverage,
  "strong reactions should tend toward higher confidence in fixture",
);

const required = [
  "types/self-recognition-ingredients.ts",
  "lib/insights/self-recognition-ingredients.ts",
  "components/internal/SelfRecognitionIngredientsPanel.tsx",
  "app/internal/blind-spot-discovery/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const pageSrc = fs.readFileSync(
  path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
if (!pageSrc.includes("SelfRecognitionIngredientsPanel")) {
  failures.push("blind-spot-discovery must render SelfRecognitionIngredientsPanel");
}
if (!pageSrc.includes("buildSelfRecognitionIngredientsReport")) {
  failures.push("blind-spot-discovery must build ingredients report");
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/internal/SelfRecognitionIngredientsPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("Common ingredients — strongest")) {
  failures.push("panel must show strongest ingredients");
}
if (!panelSrc.includes("Common ingredients — weakest")) {
  failures.push("panel must show weakest ingredients");
}
if (!panelSrc.includes("Why this felt accurate")) {
  failures.push("panel must show accuracy ingredient correlation");
}

if (!fs.readFileSync(path.join(ROOT, "package.json"), "utf8").includes("validate:self-recognition-ingredients")) {
  failures.push("package.json missing validate:self-recognition-ingredients script");
}

if (failures.length > 0) {
  console.error("validate-self-recognition-ingredients failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-self-recognition-ingredients ok");
