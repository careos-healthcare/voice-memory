#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
globalThis.window = globalThis;
globalThis.window.location = { pathname: "/internal/blind-spot-discovery" };
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

function fail(msg) {
  failures.push(msg);
}

function entry(id, day, transcript) {
  const date = new Date(`2026-01-${String(Math.min(28, day)).padStart(2, "0")}T12:00:00.000Z`);
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
    },
    durationSeconds: 40,
  };
}

const entries = [
  entry("e1", 1, "I keep saying I will start Monday at work but I never do with my partner."),
  entry("e2", 12, "I want to change but I keep doing the same thing at work and with money."),
  entry("e3", 20, "I keep avoiding the conversation with my manager and it costs me sleep."),
  entry("e4", 25, "Maybe I will eventually tell them — I don't know, I said I would quit."),
  entry("e5", 26, "I keep circling the same worry about money and work and health."),
  entry("e6", 28, "I should have spoken up but I keep waiting; wrong again about Monday."),
];

const {
  RECOGNITION_PRIORS,
  scoreInsightIngredients,
  calculateRecognitionLikelihoodScore,
  buildInsightScorecard,
  sortInsightsByRecognitionLikelihood,
  SCORECARD_HELPER_COPY,
} = await import("../lib/insights/insight-scorecard.ts");

const FORBIDDEN_SCORECARD_COPY =
  /\b(diagnos|disorder|therapy|trauma|clinical|patholog|guaranteed|certainly|the truth|fix you|cure you)\b/i;
const { buildInsightScorecardReport } = await import(
  "../lib/insights/insight-scorecard-report.ts"
);
const { buildBlindSpotReview } = await import("../lib/blind-spots/blind-spot-review.ts");
const { buildTheoryTrackerReport } = await import("../lib/theories/theory-generation.ts");
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");

clearTheorySnapshotsForEval();

assert.equal(RECOGNITION_PRIORS.cross_life_area, 52);
assert.equal(RECOGNITION_PRIORS.contradiction, 47);
assert.equal(RECOGNITION_PRIORS.cost_evidence, 45);
assert.equal(RECOGNITION_PRIORS.long_time_span, 22);
assert.equal(RECOGNITION_PRIORS.failed_prediction, 14);

const allIngredients = scoreInsightIngredients({
  contradiction: true,
  costEvidence: true,
  crossLifeArea: true,
  longTimeSpanDays: 95,
  failedPrediction: true,
});
assert.equal(allIngredients.filter((i) => i.present).length, 5, "all five ingredients");

const fullScore = calculateRecognitionLikelihoodScore(allIngredients);
assert.equal(fullScore, 100, "full priors normalize to 100");

const dominantOnly = calculateRecognitionLikelihoodScore(
  scoreInsightIngredients({
    contradiction: true,
    costEvidence: true,
    crossLifeArea: true,
    longTimeSpanDays: 10,
    failedPrediction: false,
  }),
);
const failedOnly = calculateRecognitionLikelihoodScore(
  scoreInsightIngredients({
    contradiction: false,
    costEvidence: false,
    crossLifeArea: false,
    longTimeSpanDays: 10,
    failedPrediction: true,
  }),
);
const weakOnly = calculateRecognitionLikelihoodScore(
  scoreInsightIngredients({
    contradiction: false,
    costEvidence: false,
    crossLifeArea: false,
    longTimeSpanDays: 10,
    failedPrediction: false,
  }),
);

assert.ok(dominantOnly > failedOnly, "cross+contradiction+cost should beat failed prediction alone");
assert.ok(dominantOnly > 60, "dominant ingredients should score high");
assert.ok(failedOnly <= 34, "failed prediction alone should stay low without high-value ingredients");
assert.ok(weakOnly <= 34, "no high-value ingredients must stay low");

const cards = [
  buildInsightScorecard({
    insightId: "high",
    surface: "blind_spot",
    headline: "High mix",
    sourceIds: ["e1"],
    ingredients: {
      contradiction: true,
      costEvidence: true,
      crossLifeArea: true,
      longTimeSpanDays: 100,
      failedPrediction: true,
    },
  }),
  buildInsightScorecard({
    insightId: "low",
    surface: "theory",
    headline: "Low mix",
    sourceIds: ["e2"],
    ingredients: { failedPrediction: true, longTimeSpanDays: 5 },
  }),
];
const sorted = sortInsightsByRecognitionLikelihood(cards);
assert.equal(sorted[0]?.insightId, "high");

if (FORBIDDEN_SCORECARD_COPY.test(SCORECARD_HELPER_COPY)) {
  fail("helper copy must avoid forbidden certainty/therapy language");
}
const sanitized = buildInsightScorecard({
  insightId: "x",
  surface: "theory",
  headline: "This is the truth and therapy will cure you",
  sourceIds: [],
  ingredients: {},
});
if (/truth|therapy|cure/i.test(sanitized.headline)) {
  fail("headline should be sanitized");
}

const reviewReport = buildBlindSpotReview(entries);
if (reviewReport.kind !== "ready" || !reviewReport.review.scorecard) {
  fail("blind spot review must include scorecard");
} else {
  assert.ok(reviewReport.review.scorecard.score >= 0);
  assert.ok(reviewReport.review.scorecard.ingredients.length === 5);
}

const theories = buildTheoryTrackerReport(entries, { persistSnapshots: false }).all;
if (theories.length === 0 || !theories[0].scorecard) {
  fail("theory objects must include scorecard");
}

const report = buildInsightScorecardReport(entries);
if (report.totalScored < 1) fail("report must score at least one insight");
if (report.highest.length === 0 || report.lowest.length === 0) {
  fail("report needs highest and lowest");
}
if (report.bySurface.length === 0) fail("report needs bySurface");
if (report.ingredientHitRates.length !== 5) fail("report needs five ingredient hit rates");
if (report.recommendedPriorityOrder.length === 0) {
  fail("report needs recommended priority order");
}

const reviewSrc = fs.readFileSync(
  path.join(ROOT, "components/blind-spots/BlindSpotReview.tsx"),
  "utf8",
);
const theorySrc = fs.readFileSync(path.join(ROOT, "components/theories/TheoryCard.tsx"), "utf8");
const pageSrc = fs.readFileSync(
  path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
if (!reviewSrc.includes("InsightScorecardPanel")) {
  fail("BlindSpotReview must render InsightScorecardPanel");
}
if (!theorySrc.includes("InsightScorecardPanel")) {
  fail("TheoryCard must render InsightScorecardPanel");
}
if (!pageSrc.includes("InsightScorecardInternalPanel")) {
  fail("blind-spot-discovery must render InsightScorecardInternalPanel");
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/insights/InsightScorecardPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("Recognition likelihood")) {
  fail("user panel must show Recognition likelihood");
}

if (failures.length > 0) {
  console.error("validate-insight-scorecard failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-insight-scorecard ok");
