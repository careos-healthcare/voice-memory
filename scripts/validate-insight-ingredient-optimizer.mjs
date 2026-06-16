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

const FORBIDDEN =
  /\b(diagnos|disorder|patholog|clinical|therapy|counsel|coach|treatment|mental health|you are always|guaranteed|certainly means)\b/i;

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
  "types/insight-ingredient-optimizer.ts",
  "lib/insights/insight-ingredient-optimizer.ts",
  "lib/insights/insight-ingredient-optimizer-report.ts",
  "components/internal/InsightIngredientOptimizerPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const {
  buildInsightIngredientProfile,
  classifyIngredientTier,
  ingredientOptimizerBoost,
  describeIngredientTier,
  INGREDIENT_OPTIMIZER_WEIGHTS,
  TIER_RANKING_BOOST,
  blindSpotCandidateRankingScore,
  buildInsightIngredientProfileFromCandidate,
} = await import("../lib/insights/insight-ingredient-optimizer.ts");
const { buildInsightIngredientOptimizerReport } = await import(
  "../lib/insights/insight-ingredient-optimizer-report.ts"
);
const { buildBlindSpotReview } = await import("../lib/blind-spots/blind-spot-review.ts");
const { rankBlindSpotCandidates } = await import("../lib/blind-spots/blind-spot-ranking.ts");
const { buildPatternEngineReport } = await import("../lib/patterns/pattern-engine.ts");
const {
  appendBlindSpotQualityRecordForEval,
  clearBlindSpotQualityRecordsForEval,
} = await import("../lib/blind-spots/blind-spot-quality-storage.ts");
const { clearBlindSpotFeedbackForEval, saveBlindSpotReaction } = await import(
  "../lib/blind-spots/blind-spot-feedback.ts"
);
const { buildInsightScorecardFromBlindSpotCandidate } = await import(
  "../lib/insights/insight-scorecard.ts"
);

function entry(id, day, transcript, reflection = {}) {
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
      ...reflection,
    },
    durationSeconds: 40,
  };
}

const aTier = buildInsightIngredientProfile({
  reviewId: "blind-spot:contradiction:a",
  contradictionPresent: true,
  costEvidencePresent: true,
  crossLifeAreaPresent: true,
  failedPredictionPresent: true,
});
assert.equal(aTier.tier, "a_tier");
assert.equal(aTier.presentIngredients.length, 4);
assert.equal(
  aTier.optimizerScore,
  INGREDIENT_OPTIMIZER_WEIGHTS.contradiction +
    INGREDIENT_OPTIMIZER_WEIGHTS.cost_evidence +
    INGREDIENT_OPTIMIZER_WEIGHTS.cross_life_area +
    INGREDIENT_OPTIMIZER_WEIGHTS.failed_prediction,
);

const bTier = buildInsightIngredientProfile({
  reviewId: "blind-spot:avoidance:b",
  contradictionPresent: true,
  costEvidencePresent: true,
  crossLifeAreaPresent: false,
  failedPredictionPresent: false,
});
assert.equal(bTier.tier, "b_tier");
assert.equal(classifyIngredientTier(2), "b_tier");
assert.equal(classifyIngredientTier(1), "c_tier");
assert.equal(classifyIngredientTier(0), "d_tier");

const dTier = buildInsightIngredientProfile({
  reviewId: "blind-spot:recurring_pattern:d",
  contradictionPresent: false,
  costEvidencePresent: false,
  crossLifeAreaPresent: false,
  failedPredictionPresent: false,
  evidenceStrength: "medium",
  scorecardScore: 40,
});
assert.equal(dTier.tier, "d_tier");
assert.equal(ingredientOptimizerBoost(dTier, { evidenceStrength: "medium", scorecardScore: 40 }), TIER_RANKING_BOOST.d_tier);

const spared = buildInsightIngredientProfile({
  reviewId: "blind-spot:recurring_pattern:spare",
  contradictionPresent: false,
  costEvidencePresent: false,
  crossLifeAreaPresent: false,
  failedPredictionPresent: false,
});
assert.equal(
  ingredientOptimizerBoost(spared, { evidenceStrength: "very_high", scorecardScore: 80 }),
  0,
  "D-tier penalty waived only for very_high + scorecard >= 75",
);

assert.ok(describeIngredientTier(aTier).includes("A-tier"));

clearBlindSpotQualityRecordsForEval();
clearBlindSpotFeedbackForEval();
for (let i = 0; i < 6; i++) {
  const id = `blind-spot:contradiction:q${i}`;
  appendBlindSpotQualityRecordForEval({
    reviewId: id,
    headline: `Strong ${i}`,
    contradictionPresent: true,
    costEvidencePresent: true,
    crossLifeAreaPresent: true,
    scorecardScore: 70 + i,
  });
  saveBlindSpotReaction({
    reviewId: id,
    reaction: i % 2 === 0 ? "surprising" : "uncomfortably_accurate",
    headline: `Strong ${i}`,
    evidenceStrength: "high",
    estimatedImpactScore: 70,
    reflectionCount: 8,
    archiveAgeDays: 30,
  });
}
for (let i = 0; i < 4; i++) {
  appendBlindSpotQualityRecordForEval({
    reviewId: `blind-spot:recurring_pattern:weak${i}`,
    headline: `Weak ${i}`,
    scorecardScore: 30,
    evidenceStrength: "medium",
  });
}

const optimizerReport = buildInsightIngredientOptimizerReport();
assert.ok(optimizerReport.totalProfiles >= 10);
assert.ok(optimizerReport.tierOutcomeRates.length === 4);
assert.ok(optimizerReport.ingredientOutcomeRates.length === 4);
assert.ok(optimizerReport.successMultipliers.length >= 2);
assert.ok(
  ["prioritize_a_tier", "prioritize_b_tier", "insufficient_data"].includes(
    optimizerReport.recommendation,
  ),
);

const contradictionArchive = [
  entry("c1", 1, "I want to quit my job and start fresh — I need change at work."),
  entry("c2", 10, "I keep telling myself I have to stay at work and not rock the boat."),
  entry("c3", 20, "I want to change careers but I keep doing the same thing at work."),
  entry("c4", 30, "My partner says I should leave but I keep waiting at work."),
  entry("c5", 40, "I want to speak up with my manager but I keep avoiding the conversation at work."),
  entry("c6", 50, "Money and family pressure, but I keep saying I want out of work."),
];
const frequencyArchive = [
  entry("f1", 1, "Work stress today at the office."),
  entry("f2", 2, "Work stress again at the office."),
  entry("f3", 3, "Work stress still at the office."),
  entry("f4", 4, "Work stress continues at the office."),
  entry("f5", 5, "Work stress never ends at the office."),
  entry("f6", 6, "More work stress at the office."),
];

const mixedRanked = rankBlindSpotCandidates(
  buildPatternEngineReport(contradictionArchive, { scope: "archive", limit: 40 }).insights,
  contradictionArchive,
);
const contraRow = mixedRanked.find((r) => r.insight.type === "contradiction");
const recurringRow = mixedRanked.find((r) => r.insight.type === "recurring_pattern");
if (contraRow && recurringRow) {
  const headlineC = contraRow.insight.title;
  const headlineR = recurringRow.insight.title;
  const scorecardC = buildInsightScorecardFromBlindSpotCandidate(contraRow, headlineC).score;
  const scorecardR = buildInsightScorecardFromBlindSpotCandidate(recurringRow, headlineR).score;
  const profileC = buildInsightIngredientProfileFromCandidate(contraRow, headlineC, scorecardC);
  const profileR = buildInsightIngredientProfileFromCandidate(recurringRow, headlineR, scorecardR);
  const rankC = blindSpotCandidateRankingScore(contraRow, profileC, scorecardC);
  const rankR = blindSpotCandidateRankingScore(recurringRow, profileR, scorecardR);
  assert.ok(rankC > rankR, "A-tier contradiction mix should beat D-tier recurring theme");
  assert.ok(profileC.tier === "a_tier" || profileC.tier === "b_tier");
}

const weakOnly = buildBlindSpotReview([
  entry("w1", 1, "Okay day."),
  entry("w2", 2, "Fine."),
  entry("w3", 3, "Normal."),
  entry("w4", 4, "Routine."),
  entry("w5", 5, "Nothing much."),
]);
assert.equal(weakOnly.kind, "empty", "weak evidence archive still blocked");

const ready = buildBlindSpotReview(contradictionArchive);
assert.equal(ready.kind, "ready");
if (ready.kind === "ready") {
  assert.ok(ready.review.ingredientProfile, "ready review attaches ingredient profile");
  assert.ok(ready.review.ingredientProfile.tier !== "d_tier");
}

const discoverySrc = fs.readFileSync(
  path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
if (!discoverySrc.includes("InsightIngredientOptimizerPanel")) {
  fail("blind-spot-discovery must wire optimizer panel");
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/internal/InsightIngredientOptimizerPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("Insight Ingredient Optimizer")) fail("panel title missing");
if (!panelSrc.includes("A-tier blind spots contain")) fail("A-tier copy missing");
if (!panelSrc.includes("D-tier blind spots contain none")) fail("D-tier copy missing");

for (const rel of [
  "lib/insights/insight-ingredient-optimizer.ts",
  "lib/insights/insight-ingredient-optimizer-report.ts",
  "components/internal/InsightIngredientOptimizerPanel.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (FORBIDDEN.test(src)) fail(`forbidden language in ${rel}`);
}

const rankingSrc = fs.readFileSync(
  path.join(ROOT, "lib/blind-spots/blind-spot-ranking.ts"),
  "utf8",
);
if (
  !rankingSrc.includes("blindSpotPrioritizationScore") &&
  !rankingSrc.includes("blindSpotCandidateRankingScore")
) {
  fail("ranking must use A-tier prioritization or optimizer composite score");
}

if (failures.length > 0) {
  console.error("validate-insight-ingredient-optimizer failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-insight-ingredient-optimizer ok");
