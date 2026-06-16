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

const { appendBlindSpotEventForEval, BLIND_SPOT_EVENTS } = await import(
  "../lib/blind-spots/blind-spot-events.ts"
);
const { wowMomentScoreForReaction, sumWowMomentScore } = await import(
  "../lib/blind-spots/wow-moment-score.ts"
);
const {
  clearBlindSpotFeedbackForEval,
  saveBlindSpotReaction,
  readAllBlindSpotFeedback,
} = await import("../lib/blind-spots/blind-spot-feedback.ts");
const {
  clearDelayedValidationsForEval,
  scheduleDelayedValidation,
  getDueDelayedValidations,
  saveDelayedValidationResponse,
} = await import("../lib/blind-spots/delayed-validation.ts");
const {
  clearBreakthroughCapturesForEval,
  saveBreakthroughCapture,
  readAllBreakthroughCaptures,
} = await import("../lib/blind-spots/breakthrough-capture.ts");
const { buildSelfRecognitionAnalysis } = await import(
  "../lib/blind-spots/self-recognition-analysis.ts"
);
const { buildEmergingPatterns } = await import("../lib/blind-spots/emerging-patterns.ts");
const { BLIND_SPOT_EVIDENCE_FIRST_SECTIONS } = await import(
  "../types/blind-spot-acceleration.ts"
);

clearBlindSpotFeedbackForEval();
clearDelayedValidationsForEval();
clearBreakthroughCapturesForEval();
storage.delete("voicememory_local_events");

// Wow scoring
assert.equal(wowMomentScoreForReaction("uncomfortably_accurate"), 3);
assert.equal(wowMomentScoreForReaction("completely_wrong"), -3);
assert.equal(
  sumWowMomentScore(["surprising", "uncomfortably_accurate"]),
  5,
);

const eightDaysAgo = new Date();
eightDaysAgo.setDate(eightDaysAgo.getDate() - 8);

saveBlindSpotReaction({
  reviewId: "blind-spot:avoidance_signal:test",
  reaction: "obvious",
  headline: "One possible pattern: circling",
  evidenceStrength: "medium",
  estimatedImpactScore: 50,
  reflectionCount: 6,
  archiveAgeDays: 21,
});

const weak = saveBlindSpotReaction({
  reviewId: "blind-spot:avoidance_signal:test",
  reaction: "completely_wrong",
  headline: "One possible pattern: circling",
  evidenceStrength: "medium",
  estimatedImpactScore: 50,
  reflectionCount: 6,
  archiveAgeDays: 21,
});

scheduleDelayedValidation({
  feedbackId: weak.id,
  reviewId: weak.reviewId,
  headline: weak.headline,
  reaction: "completely_wrong",
  reactedAt: eightDaysAgo.toISOString(),
});

const due = getDueDelayedValidations();
if (due.length < 1) {
  failures.push("expected due delayed validation prompt");
}

saveDelayedValidationResponse(due[0].id, "changed_mind");

saveBlindSpotReaction({
  reviewId: "blind-spot:repeated_phrase:keep",
  reaction: "surprising",
  headline: "Returning to I keep",
  evidenceStrength: "high",
  estimatedImpactScore: 72,
  reflectionCount: 8,
  archiveAgeDays: 45,
});

const strong = saveBlindSpotReaction({
  reviewId: "blind-spot:repeated_phrase:keep",
  reaction: "uncomfortably_accurate",
  headline: "Returning to I keep",
  evidenceStrength: "high",
  estimatedImpactScore: 72,
  reflectionCount: 8,
  archiveAgeDays: 45,
});

const breakthrough = saveBreakthroughCapture({
  feedbackId: strong.id,
  reviewId: strong.reviewId,
  reaction: "uncomfortably_accurate",
  phrase: "The part about avoiding the real conversation",
});
if (!breakthrough) {
  failures.push("breakthrough capture should save");
}

appendBlindSpotEventForEval(BLIND_SPOT_EVENTS.blindSpotOpened, {
  reviewId: "blind-spot:repeated_phrase:keep",
  reflectionCount: 8,
});
appendBlindSpotEventForEval(BLIND_SPOT_EVENTS.emergingPatternOpened, { reflectionCount: 3 });
appendBlindSpotEventForEval(BLIND_SPOT_EVENTS.predictionReviewOpened, { reflectionCount: 8 });
appendBlindSpotEventForEval(BLIND_SPOT_EVENTS.predictionAccuracyOpened, { reflectionCount: 8 });

const feedback = readAllBlindSpotFeedback();
const report = buildSelfRecognitionAnalysis(feedback);

if (report.topWowMoments[0]?.wowMomentScore < 3) {
  failures.push("top wow moment should rank strong reactions highest");
}
if (report.highestRecognitionPatterns.length === 0) {
  failures.push("expected pattern category rows");
}
if (report.surfaceOpens.blindSpotOpened < 1) {
  failures.push("expected blind_spot_opened events");
}
if (report.breakthroughPhrases.length === 0) {
  failures.push("expected breakthrough phrase summary");
}
if (report.delayedValidation.changedMind < 1) {
  failures.push("expected delayed validation response");
}

const emerging = buildEmergingPatterns([
  {
    id: "e1",
    createdAt: "2026-02-01T12:00:00.000Z",
    transcript: "I keep avoiding the talk.",
    reflection: {
      mood: "tense",
      emotionalIntensity: 5,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 30,
  },
  {
    id: "e2",
    createdAt: "2026-02-05T12:00:00.000Z",
    transcript: "I keep putting off the same decision.",
    reflection: {
      mood: "tense",
      emotionalIntensity: 5,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 30,
  },
]);
if (emerging.length < 1 || emerging[0].label !== "Possible emerging pattern") {
  failures.push("emerging patterns should surface at 2+ reflections");
}

assert.deepEqual(BLIND_SPOT_EVIDENCE_FIRST_SECTIONS[0], "evidence");

const reviewSrc = fs.readFileSync(
  path.join(ROOT, "components/blind-spots/BlindSpotReview.tsx"),
  "utf8",
);
if (!reviewSrc.includes("BreakthroughCapturePrompt") || !reviewSrc.includes("DelayedValidationPrompt")) {
  failures.push("BlindSpotReview must include breakthrough and delayed validation");
}
if (!fs.existsSync(path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx"))) {
  failures.push("missing discovery dashboard route");
}

console.log(
  JSON.stringify(
    {
      topWow: report.topWowMoments[0],
      breakthroughPhrases: report.breakthroughPhrases,
      delayedValidation: report.delayedValidation,
      surfaceOpens: report.surfaceOpens,
    },
    null,
    2,
  ),
);

if (failures.length > 0) {
  console.error("validate-blind-spot-discovery failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-blind-spot-discovery ok");
