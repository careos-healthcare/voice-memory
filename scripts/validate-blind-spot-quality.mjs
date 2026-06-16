#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

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

const required = [
  "types/blind-spot-quality.ts",
  "lib/blind-spots/blind-spot-quality-storage.ts",
  "lib/blind-spots/blind-spot-quality-score.ts",
  "lib/blind-spots/blind-spot-quality-enrichment.ts",
  "lib/blind-spots/blind-spot-quality-report.ts",
  "components/internal/BlindSpotQualityPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const { computeBlindSpotQualityScore, hasAnyQualityOutcome } = await import(
  "../lib/blind-spots/blind-spot-quality-score.ts"
);
const {
  appendBlindSpotQualityRecordForEval,
  blindSpotIdFromReviewId,
  clearBlindSpotQualityRecordsForEval,
  persistBlindSpotQualityFromReview,
  readAllBlindSpotQualityRecords,
} = await import("../lib/blind-spots/blind-spot-quality-storage.ts");
const { enrichBlindSpotQualityRecord } = await import(
  "../lib/blind-spots/blind-spot-quality-enrichment.ts"
);
const { buildBlindSpotQualityReport } = await import(
  "../lib/blind-spots/blind-spot-quality-report.ts"
);
const { saveBlindSpotReaction, clearBlindSpotFeedbackForEval } = await import(
  "../lib/blind-spots/blind-spot-feedback.ts"
);
const { saveBreakthroughCapture, clearBreakthroughCapturesForEval } = await import(
  "../lib/blind-spots/breakthrough-capture.ts"
);
const {
  scheduleInsightOutcomeOffer,
  saveInsightOutcomeResponse,
  clearInsightOutcomeForEval,
} = await import("../lib/insights/insight-outcome-storage.ts");
const { buildBlindSpotReview } = await import("../lib/blind-spots/blind-spot-review.ts");
const { persistBlindSpotReviewSnapshot, clearBlindSpotReviewSnapshotsForEval } =
  await import("../lib/blind-spots/blind-spot-review-snapshots.ts");

clearBlindSpotQualityRecordsForEval();
clearBlindSpotFeedbackForEval();
clearBreakthroughCapturesForEval();
clearInsightOutcomeForEval();
clearBlindSpotReviewSnapshotsForEval();

assert.equal(
  blindSpotIdFromReviewId("blind-spot:contradiction:abc"),
  "contradiction:abc",
);

const emptyScore = computeBlindSpotQualityScore({
  surprising: false,
  uncomfortablyAccurate: false,
  breakthrough: false,
  actedDifferently: false,
  problemImproved: false,
});
assert.equal(emptyScore, 0);

const fullScore = computeBlindSpotQualityScore({
  surprising: true,
  uncomfortablyAccurate: true,
  breakthrough: true,
  actedDifferently: true,
  problemImproved: true,
});
assert.ok(fullScore >= 90 && fullScore <= 100);
assert.ok(hasAnyQualityOutcome({ surprising: true, uncomfortablyAccurate: false, breakthrough: false, actedDifferently: false, problemImproved: false }));

appendBlindSpotQualityRecordForEval({
  reviewId: "blind-spot:contradiction:weak",
  headline: "Weak pattern",
  contradictionPresent: false,
  scorecardScore: 30,
});
const strong = appendBlindSpotQualityRecordForEval({
  reviewId: "blind-spot:contradiction:strong",
  headline: "Strong pattern",
  contradictionPresent: true,
  costEvidencePresent: true,
  scorecardScore: 72,
});

saveBlindSpotReaction({
  reviewId: strong.reviewId,
  reaction: "uncomfortably_accurate",
  headline: strong.headline,
  evidenceStrength: "high",
  estimatedImpactScore: 70,
  reflectionCount: 8,
  archiveAgeDays: 40,
});

saveBlindSpotReaction({
  reviewId: strong.reviewId,
  reaction: "surprising",
  headline: strong.headline,
  evidenceStrength: "high",
  estimatedImpactScore: 70,
  reflectionCount: 8,
  archiveAgeDays: 40,
});

const feedback = saveBlindSpotReaction({
  reviewId: strong.reviewId,
  reaction: "uncomfortably_accurate",
  headline: strong.headline,
  evidenceStrength: "high",
  estimatedImpactScore: 70,
  reflectionCount: 8,
  archiveAgeDays: 40,
});

saveBreakthroughCapture({
  feedbackId: feedback.id,
  reviewId: strong.reviewId,
  reaction: "uncomfortably_accurate",
  phrase: "I finally saw the loop",
});

scheduleInsightOutcomeOffer(
  {
    insightId: strong.reviewId,
    insightType: "blind_spot",
    scorecardScore: 72,
    contradictionPresent: true,
    costEvidencePresent: true,
    crossLifeAreaPresent: false,
    failedPredictionPresent: false,
    longSpanPresent: true,
  },
  "experiment_followup",
);
saveInsightOutcomeResponse("acted_differently");

const enriched = enrichBlindSpotQualityRecord(strong);
assert.equal(enriched.outcomes.uncomfortablyAccurate, true);
assert.equal(enriched.outcomes.breakthrough, true);
assert.equal(enriched.outcomes.actedDifferently, true);
assert.ok(enriched.blindSpotQualityScore > emptyScore);

const report = buildBlindSpotQualityReport();
assert.ok(report.totalRecords >= 2);
assert.ok(report.topPerformers.length >= 1);
assert.equal(report.topPerformers[0]?.reviewId, strong.reviewId);
assert.ok(report.ingredientFrequencies.length >= 5);
assert.ok(report.successMultipliers.some((r) => r.line.includes("Contradictions")));

const snapshotSrc = fs.readFileSync(
  path.join(ROOT, "lib/blind-spots/blind-spot-review-snapshots.ts"),
  "utf8",
);
if (!snapshotSrc.includes("persistBlindSpotQualityFromReview")) {
  fail("snapshots must persist quality records on save");
}

const discoverySrc = fs.readFileSync(
  path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
if (!discoverySrc.includes("BlindSpotQualityPanel")) {
  fail("blind-spot-discovery must wire BlindSpotQualityPanel");
}
const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/internal/BlindSpotQualityPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("What creates the strongest blind spots")) {
  fail("BlindSpotQualityPanel must include title");
}

const scoreSrc = fs.readFileSync(
  path.join(ROOT, "lib/blind-spots/blind-spot-quality-score.ts"),
  "utf8",
);
if (!scoreSrc.includes("QUALITY_WEIGHTS")) {
  fail("quality score must use QUALITY_WEIGHTS only");
}
assert.ok(!scoreSrc.includes("blindSpotOpened"));
assert.ok(!scoreSrc.includes("pageView"));

function entry(id, day, transcript) {
  const month = day > 28 ? "02" : "01";
  const dayInMonth = day > 28 ? day - 28 : day;
  return {
    id,
    createdAt: new Date(
      `2026-${month}-${String(dayInMonth).padStart(2, "0")}T12:00:00.000Z`,
    ).toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 40,
  };
}

const lines = [
  "I keep saying I will start Monday but I never do.",
  "I want to change but I keep doing the same thing at work.",
  "I keep avoiding the conversation with my manager.",
  "Maybe I will eventually tell them — I don't know.",
  "I keep circling the same worry about money and work.",
  "I should have spoken up but I keep waiting to quit.",
];
const archive = lines.map((t, i) => entry(`e${i + 1}`, (i + 1) * 5, t));
const ready = buildBlindSpotReview(archive);
assert.equal(ready.kind, "ready");
persistBlindSpotReviewSnapshot(ready.review);
const fromReview = readAllBlindSpotQualityRecords().find(
  (r) => r.reviewId === ready.review.reviewId,
);
assert.ok(fromReview, "snapshot save should create quality record");
assert.equal(persistBlindSpotQualityFromReview(ready.review).reviewId, ready.review.reviewId);

if (failures.length > 0) {
  console.error("validate-blind-spot-quality failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-blind-spot-quality ok");
