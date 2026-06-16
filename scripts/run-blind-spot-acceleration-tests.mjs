#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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

const { clearPredictionCandidatesForEval, extractPredictionsFromText, syncPredictionCandidates } =
  await import("../lib/blind-spots/prediction-detection.ts");
const { buildEmergingPatterns } = await import("../lib/blind-spots/emerging-patterns.ts");
const { buildCostEvidence } = await import("../lib/blind-spots/cost-evidence.ts");
const { buildPredictionReview, buildPredictionAccuracySummary } = await import(
  "../lib/blind-spots/prediction-review.ts"
);
const { buildBlindSpotAccelerationReport } = await import(
  "../lib/blind-spots/blind-spot-acceleration.ts"
);
const { BLIND_SPOT_EVIDENCE_FIRST_SECTIONS } = await import(
  "../types/blind-spot-acceleration.ts"
);

clearPredictionCandidatesForEval();

function baseReflection(overrides = {}) {
  return {
    mood: "tense",
    emotionalIntensity: 6,
    recurringThemes: ["work"],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    ...overrides,
  };
}

function entry(id, day, transcript, reflection = {}) {
  const date = new Date(`2026-02-${String(day).padStart(2, "0")}T12:00:00.000Z`);
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: baseReflection(reflection),
    durationSeconds: 40,
  };
}

// Prediction extraction
const preds = extractPredictionsFromText(
  "e-pred",
  "2026-02-01T12:00:00.000Z",
  "I think this will fail badly. I'm sure Monday will be terrible.",
);
assert.ok(preds.length >= 2);
assert.ok(preds.some((p) => p.triggerPhrase === "I think"));
assert.ok(preds.some((p) => p.polarity === "negative"));

// Emerging patterns (2+ reflections)
const emergingEntries = [
  entry("e1", 1, "I keep avoiding the talk with my manager."),
  entry("e2", 5, "I keep putting off the same decision at work."),
];
const emerging = buildEmergingPatterns(emergingEntries);
assert.ok(emerging.length >= 1);
assert.equal(emerging[0].label, "Possible emerging pattern");
assert.equal(emerging[0].confidenceLabel, "Low confidence");
assert.ok(emerging[0].hypothesis.includes("may"));
assert.ok(emerging[0].evidenceQuotes.length >= 2);

// Cost evidence
const costEntries = [
  entry("e1", 1, "I keep avoiding the conversation."),
  entry("e2", 3, "I put off the decision again and feel stuck."),
  entry("e3", 6, "I want to quit and escape this whole situation."),
];
const costs = buildCostEvidence(["e1"], costEntries);
assert.ok(costs.avoidance + costs.delayedDecisions + costs.quittingLanguage >= 1);

// Prediction vs reality
const predictionEntries = [
  entry("e1", 1, "I think this will fail and I will mess up the presentation."),
  entry("e2", 8, "It went better than I expected and I felt relieved afterward."),
];
clearPredictionCandidatesForEval();
const candidates = syncPredictionCandidates(predictionEntries);
const predReview = buildPredictionReview(candidates, predictionEntries);
assert.ok(predReview.hasData);
const diverged = predReview.items.find((i) => i.outcomeStatus === "diverged");
assert.ok(diverged);
assert.ok(diverged.laterEvidence);

const accuracy = buildPredictionAccuracySummary(predReview.items);
assert.ok(accuracy.summaryLines.length >= 1);
assert.ok(
  accuracy.summaryLines.some((l) => /negative prediction|predicted failure/i.test(l)),
);

// Full acceleration report
const fullEntries = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "I think this will fail if I speak up."),
  entry("e5", 20, "It went better than I expected — I finally talked to them."),
  entry("e6", 28, "I should have spoken up but I keep waiting."),
];
clearPredictionCandidatesForEval();
const acceleration = buildBlindSpotAccelerationReport(fullEntries);
assert.ok(acceleration.emergingPatterns.length >= 1);
assert.equal(acceleration.mainReview.kind, "ready");
if (acceleration.mainReview.kind === "ready") {
  assert.ok(acceleration.mainReview.review.observation.includes("suggest"));
  assert.ok(Array.isArray(acceleration.mainReview.review.costEvidenceLines));
}

assert.deepEqual(BLIND_SPOT_EVIDENCE_FIRST_SECTIONS, [
  "evidence",
  "observation",
  "possiblePattern",
  "whyItMayMatter",
]);

const reviewSrc = fs.readFileSync(
  path.join(ROOT, "components/blind-spots/BlindSpotReview.tsx"),
  "utf8",
);
assert.ok(reviewSrc.includes("BLIND_SPOT_EVIDENCE_FIRST_SECTIONS"));
const evidenceIdx = reviewSrc.indexOf("evidenceSection");
const observationIdx = reviewSrc.indexOf("observationSection");
const patternIdx = reviewSrc.indexOf("patternSection");
const whyIdx = reviewSrc.indexOf("whySection");
assert.ok(
  evidenceIdx > 0 &&
    observationIdx > evidenceIdx &&
    patternIdx > observationIdx &&
    whyIdx > patternIdx,
);
assert.ok(
  reviewSrc.indexOf("{evidenceSection}") < reviewSrc.indexOf("{observationSection}") &&
    reviewSrc.indexOf("{observationSection}") < reviewSrc.indexOf("{patternSection}") &&
    reviewSrc.indexOf("{patternSection}") < reviewSrc.indexOf("{whySection}"),
);

const pageSrc = fs.readFileSync(path.join(ROOT, "app/blind-spots/page.tsx"), "utf8");
assert.ok(pageSrc.includes("BlindSpotAccelerationView"));
assert.ok(pageSrc.includes("PredictionReviewSection") === false);
assert.ok(
  fs.readFileSync(path.join(ROOT, "components/blind-spots/BlindSpotAccelerationView.tsx"), "utf8").includes(
    "PredictionReviewSection",
  ),
);

console.log("run-blind-spot-acceleration-tests ok");
