#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const required = [
  "packages/shared/types/a-tier-prioritization.ts",
  "packages/shared/lib/blind-spots/a-tier-prioritization.ts",
  "packages/shared/lib/blind-spots/a-tier-quality-dashboard.ts",
  "apps/web/components/blind-spots/EvidenceQualityBadge.tsx",
  "apps/web/components/internal/ATierQualityDashboardPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const prioritization = read("packages/shared/lib/blind-spots/a-tier-prioritization.ts");
if (!prioritization.includes("blindSpotPrioritizationScore")) {
  fail("a-tier-prioritization must export blindSpotPrioritizationScore");
}
if (!prioritization.includes("buildATierWhyMatterBullets")) {
  fail("A-tier why-matter bullets missing");
}
if (!prioritization.includes("subtleEvidenceQualityLabel")) {
  fail("subtle evidence quality labels missing");
}

const badge = read("apps/web/components/blind-spots/EvidenceQualityBadge.tsx");
if (badge.includes("optimizerScore")) fail("must not show raw optimizer score in UI");
if (!badge.includes("subtleEvidenceQualityLabel") && !badge.includes("aTier")) {
  fail("EvidenceQualityBadge must use subtle tier labels");
}

const reviewUi = read("apps/web/components/blind-spots/BlindSpotReview.tsx");
if (!reviewUi.includes("EvidenceQualityBadge")) {
  fail("BlindSpotReview must show EvidenceQualityBadge");
}
if (!reviewUi.includes("whyMatterBullets")) {
  fail("BlindSpotReview must render A-tier why matter bullets");
}

const ranking = read("packages/shared/lib/blind-spots/blind-spot-ranking.ts");
if (!ranking.includes("blindSpotPrioritizationScore")) {
  fail("ranking must use blindSpotPrioritizationScore");
}

const dashboard = read("apps/web/components/internal/ATierQualityDashboardPanel.tsx");
for (const label of [
  "A-tier rate",
  "B-tier rate",
  "C-tier rate",
  "Breakthrough",
  "Pay conversion",
  "7-day return",
]) {
  if (!dashboard.includes(label)) fail(`dashboard missing ${label}`);
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

const {
  subtleEvidenceQualityLabel,
  blindSpotPrioritizationScore,
  buildATierWhyMatterBullets,
} = await import("../../packages/shared/lib/blind-spots/a-tier-prioritization.ts");
const {
  classifyIngredientTier: tierFromOptimizer,
  buildInsightIngredientProfile,
} = await import("../../packages/shared/lib/insights/insight-ingredient-optimizer.ts");
const { buildInsightScorecardFromBlindSpotCandidate } = await import(
  "../../packages/shared/lib/insights/insight-scorecard.ts"
);
const { rankBlindSpotCandidates } = await import("../../packages/shared/lib/blind-spots/blind-spot-ranking.ts");
const { buildPatternEngineReport } = await import("../../packages/shared/lib/patterns/pattern-engine.ts");
const { buildATierQualityDashboardReport } = await import(
  "../../packages/shared/lib/blind-spots/a-tier-quality-dashboard.ts"
);

assert.equal(subtleEvidenceQualityLabel("a_tier"), "A-Tier");
assert.equal(subtleEvidenceQualityLabel("b_tier"), "B-Tier");
assert.equal(subtleEvidenceQualityLabel("c_tier"), "C-Tier");
assert.equal(subtleEvidenceQualityLabel("d_tier"), null);

assert.equal(tierFromOptimizer(3), "a_tier");
assert.equal(tierFromOptimizer(2), "b_tier");
assert.equal(tierFromOptimizer(1), "c_tier");
assert.equal(tierFromOptimizer(0), "d_tier");

function entry(id, day, transcript) {
  const month = day > 28 ? "02" : "01";
  const d = day > 28 ? day - 28 : day;
  return {
    id,
    createdAt: new Date(`2026-${month}-${String(d).padStart(2, "0")}T12:00:00.000Z`).toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work", "relationships"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: "You sound stuck.",
      repeatedSignal: "You keep circling the same worry.",
    },
    durationSeconds: 40,
  };
}

const richEntries = [
  entry("e1", 1, "At work I keep avoiding the hard conversation with my manager."),
  entry("e2", 8, "My partner says I shut down — I thought I would speak up but I never do."),
  entry("e3", 16, "I said I would start Monday and I keep doing the same thing."),
  entry("e4", 24, "Money stress and relationship tension keep showing up together."),
  entry("e5", 32, "I keep circling the same worry — I want to change but I don't."),
  entry("e6", 40, "I should have quit but I keep waiting — the cost keeps landing later."),
];

const report = buildPatternEngineReport(richEntries, { scope: "archive", limit: 40 });
const ranked = rankBlindSpotCandidates(report.insights, richEntries);
assert.ok(ranked.length > 0, "expected ranked blind spot candidates");

const winner = ranked[0];
const headline = winner.insight.title;
const scorecardScore = buildInsightScorecardFromBlindSpotCandidate(winner, headline).score;
const profile = buildInsightIngredientProfile({
  reviewId: `blind-spot:${winner.insight.type}:${winner.insight.sourceKey}`,
  contradictionPresent: winner.contradictionPresent,
  costEvidencePresent: winner.costEvidenceCount > 0,
  crossLifeAreaPresent: winner.lifeAreaCount >= 2,
  failedPredictionPresent: winner.failedPredictionLinked,
  evidenceStrength: winner.evidenceStrength,
  scorecardScore,
});

const generic = ranked.find((c) => c.insight.type === "repeated_phrase");
if (generic) {
  const genericProfile = buildInsightIngredientProfile({
    reviewId: "x",
    contradictionPresent: false,
    costEvidencePresent: false,
    crossLifeAreaPresent: false,
    failedPredictionPresent: false,
    scorecardScore: 40,
  });
  const aProfile = buildInsightIngredientProfile({
    reviewId: "y",
    contradictionPresent: true,
    costEvidencePresent: true,
    crossLifeAreaPresent: true,
    failedPredictionPresent: false,
    scorecardScore: 55,
  });
  const aScore = blindSpotPrioritizationScore(winner, aProfile, 55);
  const gScore = blindSpotPrioritizationScore(generic, genericProfile, 40);
  assert.ok(aScore > gScore, "A-tier mix should beat generic phrase repetition");
}

if (profile.tier === "a_tier") {
  const mockReview = {
    reviewId: `blind-spot:${winner.insight.type}:${winner.insight.sourceKey}`,
    headline,
    observation: "test",
    possibleBelief: "test",
    pattern: "test",
    costEvidence: {},
    costEvidenceLines: ["later cost"],
    likelyCost: "test",
    evidenceQuotes: [],
    evidenceStrength: winner.evidenceStrength,
    evidenceStrengthFacts: {
      reflectionCount: 5,
      spanLabel: "3 weeks",
      spanDays: 21,
      richSpanLabel: "3 weeks",
      lifeAreaCount: 2,
      lifeAreas: ["Work", "Relationships"],
      contradictionPresent: true,
      failedPredictionCount: 0,
      costEvidenceCount: 1,
      specificityScore: 60,
      skepticPass: true,
    },
    linkedAreas: ["Work", "Relationships"],
    alternativeToTest: "test",
    ifThisDisappeared: "test",
    whyThisMatters: "test",
    disclaimer: "test",
    reflectionCount: 6,
    archiveEntryIds: richEntries.map((e) => e.id),
    estimatedImpactScore: winner.impactScore,
    generatedAt: new Date().toISOString(),
    ingredientProfile: profile,
  };
  const bullets = buildATierWhyMatterBullets(mockReview, profile, richEntries);
  assert.ok(bullets.length >= 1, "A-tier review needs why-matter bullets");
}

const dash = buildATierQualityDashboardReport();
assert.ok(dash.tierRows.length === 4);

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
}

if (failures.length) {
  console.error("validate-a-tier-prioritization failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-a-tier-prioritization ok");
