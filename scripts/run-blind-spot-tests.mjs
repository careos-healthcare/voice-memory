#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

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

import { buildCostEvidence } from "../lib/blind-spots/cost-evidence.ts";
import { buildBlindSpotReview } from "../lib/blind-spots/blind-spot-review.ts";
import {
  BLIND_SPOT_EMPTY_MESSAGE,
  BLIND_SPOT_WEAK_EVIDENCE_MESSAGE,
} from "../lib/blind-spots/blind-spot-copy.ts";
import {
  contradictionRankBoost,
  costEvidenceRankBoost,
  deriveRootBeliefHypothesis,
  failedPredictionRankBoost,
  FORBIDDEN_ROOT_BELIEF,
  passesSkepticEvidenceGate,
} from "../lib/blind-spots/evidence-accuracy.ts";
import {
  computeEvidenceStrength,
  rankBlindSpotCandidates,
} from "../lib/blind-spots/blind-spot-ranking.ts";
import { buildPredictionReview } from "../lib/blind-spots/prediction-review.ts";
import { syncPredictionCandidates } from "../lib/blind-spots/prediction-detection.ts";
import { buildPatternEngineReport } from "../lib/patterns/pattern-engine.ts";

const FORBIDDEN_RE =
  /\b(diagnos|disorder|patholog|clinical|trauma|therapy|guaranteed|will always cause)\b/i;

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
  const month = day > 28 ? "02" : "01";
  const dayInMonth = day > 28 ? day - 28 : day;
  const date = new Date(
    `2026-${month}-${String(dayInMonth).padStart(2, "0")}T12:00:00.000Z`,
  );
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: baseReflection(reflection),
    durationSeconds: 40,
  };
}

function assertNoOverclaiming(review) {
  const blob = [
    review.headline,
    review.possibleBelief,
    review.pattern,
    review.likelyCost,
    review.ifThisDisappeared,
    review.alternativeToTest,
    review.whyThisMatters,
    review.experiment?.smallThing,
    review.experiment?.tryNextTime,
    review.experiment?.checkWhether,
  ].join(" ");
  assert.ok(!FORBIDDEN_RE.test(blob), `overclaiming language: ${blob.slice(0, 120)}`);
  assert.ok(review.possibleBelief.includes("suggest") || review.possibleBelief.includes("may"));
  assert.ok(
    review.headline.includes("possible pattern") || review.headline.includes("One possible"),
  );
}

// Fewer than 5 reflections → insufficient empty state
const sparse = [entry("e1", 1, "I keep putting this off again.")];
const emptyReport = buildBlindSpotReview(sparse);
assert.equal(emptyReport.kind, "empty");
if (emptyReport.kind === "empty") {
  assert.equal(emptyReport.reason, "insufficient_reflections");
  assert.equal(emptyReport.message, BLIND_SPOT_EMPTY_MESSAGE);
  assert.equal(emptyReport.reflectionCount, 1);
}

// Weak themes only — no serious blind spot
const weakThemes = [
  entry("e1", 1, "Coffee was good today.", { recurringThemes: ["morning"] }),
  entry("e2", 3, "Walked in the park.", { recurringThemes: ["health"] }),
  entry("e3", 5, "Read a chapter of a book.", { recurringThemes: ["learning"] }),
  entry("e4", 7, "Called a friend briefly.", { recurringThemes: ["social"] }),
  entry("e5", 9, "Cooked dinner at home.", { recurringThemes: ["home"] }),
];
const weakReport = buildBlindSpotReview(weakThemes);
assert.equal(weakReport.kind, "empty");
if (weakReport.kind === "empty") {
  assert.equal(weakReport.reason, "weak_evidence");
  assert.equal(weakReport.message, BLIND_SPOT_WEAK_EVIDENCE_MESSAGE);
}

// Evidence strength tiers
const mediumStrength = computeEvidenceStrength({
  matchingReflections: 3,
  spanDays: 10,
  lifeAreaCount: 2,
  signalBonus: 8,
});
assert.equal(mediumStrength.label, "medium");

const lowStrength = computeEvidenceStrength({
  matchingReflections: 2,
  spanDays: 1,
  lifeAreaCount: 1,
  signalBonus: 0,
});
assert.equal(lowStrength.label, "low");

// Strong cross-entry pattern → ready blind spot
const repeating = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 28, "I should have spoken up but I keep waiting to quit."),
];

const readyReport = buildBlindSpotReview(repeating);
assert.equal(readyReport.kind, "ready");
if (readyReport.kind === "ready") {
  const { review } = readyReport;
  assert.ok(review.headline.length > 0);
  assert.ok(review.possibleBelief.includes("Your words suggest"));
  assert.ok(review.pattern.includes("This may be"));
  assert.ok(review.evidenceQuotes.length >= 2);
  assert.ok(["medium", "high", "very_high"].includes(review.evidenceStrength));
  assert.ok(review.evidenceStrengthFacts.reflectionCount >= 3);
  assert.ok(review.evidenceStrengthFacts.spanLabel.length > 0);
  assert.ok(review.evidenceStrengthFacts.lifeAreaCount >= 1);
  assert.ok(review.likelyCost.includes("This may"));
  assert.ok(review.ifThisDisappeared.includes("If this pattern softened"));
  assert.ok(review.alternativeToTest.includes("One alternative"));
  assert.ok(review.linkedAreas.length > 0);
  assert.ok(typeof review.estimatedImpactScore === "number" && review.estimatedImpactScore > 0);
  assert.ok(review.observation.includes("suggest"));
  assert.ok(Array.isArray(review.costEvidenceLines));
  assertNoOverclaiming(review);
  for (const item of review.evidenceQuotes) {
    assert.ok(item.dateLabel.length > 0);
    assert.ok(item.quote.length > 0);
  }
  assert.ok(review.evidenceStrengthFacts.richSpanLabel.length > 0);
  assert.ok(typeof review.evidenceStrengthFacts.spanDays === "number");
  assert.ok(typeof review.specificityScore === "number");
  assert.ok(review.evidenceStrengthFacts.skepticPass === true);
}

// Skeptic gate suppresses vague generic-only patterns
const genericOnly = [
  entry("g1", 1, "Had a normal day at work."),
  entry("g2", 2, "Another normal day at work."),
  entry("g3", 3, "Work was fine today."),
  entry("g4", 4, "Nothing special at work."),
  entry("g5", 5, "Routine work day again."),
];
const genericReport = buildBlindSpotReview(genericOnly);
assert.equal(genericReport.kind, "empty");
if (genericReport.kind === "empty") {
  assert.equal(genericReport.reason, "weak_evidence");
}

assert.equal(
  passesSkepticEvidenceGate({
    hasContradiction: false,
    hasFailedPrediction: false,
    spanDays: 5,
    lifeAreaCount: 1,
    costEvidenceCount: 0,
    isWeakOrGeneric: false,
  }),
  false,
);
assert.equal(
  passesSkepticEvidenceGate({
    hasContradiction: true,
    hasFailedPrediction: false,
    spanDays: 5,
    lifeAreaCount: 1,
    costEvidenceCount: 0,
    isWeakOrGeneric: false,
  }),
  true,
);

// Contradiction ranks above frequency-only recurring pattern
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
const contraReport = buildPatternEngineReport(contradictionArchive, { scope: "archive", limit: 40 });
const freqReport = buildPatternEngineReport(frequencyArchive, { scope: "archive", limit: 40 });
assert.ok(contradictionRankBoost("contradiction") > contradictionRankBoost("recurring_pattern"));
const mixedRanked = rankBlindSpotCandidates(contraReport.insights, contradictionArchive);
const contraRow = mixedRanked.find((r) => r.insight.type === "contradiction");
const recurringRow = mixedRanked.find((r) => r.insight.type === "recurring_pattern");
if (contraRow && recurringRow) {
  assert.ok(
    contraRow.impactScore > recurringRow.impactScore,
    "contradiction should beat recurring_pattern in same archive",
  );
}
const freqOnly = rankBlindSpotCandidates(
  freqReport.insights.filter((i) => i.type === "recurring_pattern"),
  frequencyArchive,
);
const contraOnly = rankBlindSpotCandidates(
  contraReport.insights.filter((i) => i.type === "contradiction"),
  contradictionArchive,
);
if (contraOnly[0] && freqOnly[0]) {
  assert.ok(contraOnly[0].impactScore > freqOnly[0].impactScore);
}

// Failed prediction beats generic concern repetition
const predictionArchive = [
  entry("p1", 1, "I think this will fall apart at work and I will mess it up."),
  entry("p2", 3, "Lunch was fine — nothing about outcomes."),
  entry("p3", 6, "Walked outside for ten minutes."),
  entry("p4", 10, "Read emails at my desk."),
  entry("p5", 15, "Routine admin tasks only."),
  entry("p6", 28, "It went better than I feared — I finally spoke up at work."),
];
assert.ok(failedPredictionRankBoost(true) > failedPredictionRankBoost(false));
const predItems = buildPredictionReview(
  syncPredictionCandidates(predictionArchive),
  predictionArchive,
).items;
const divergedPred = predItems.find((i) => i.outcomeStatus === "diverged");
assert.ok(divergedPred, "fixture should include a diverged prediction");
const predLinkedRanked = rankBlindSpotCandidates(
  buildPatternEngineReport(predictionArchive, { scope: "archive", limit: 40 }).insights,
  predictionArchive,
);
const linkedWinner = predLinkedRanked.find((r) => r.failedPredictionLinked);
assert.ok(linkedWinner, "ranking should boost insights linked to failed predictions");
assert.ok(linkedWinner.impactScore > 0);
const unlinked = predLinkedRanked.filter((r) => !r.failedPredictionLinked);
if (unlinked.length > 0) {
  assert.ok(
    linkedWinner.impactScore >= unlinked[unlinked.length - 1].impactScore,
    "prediction-linked insight should rank at least as high as weakest non-linked",
  );
}

// Cost evidence increases rank when present
const costArchive = [
  entry("k1", 1, "I keep avoiding the hard conversation at work."),
  entry("k2", 8, "I want to change but I keep doing the same thing at work."),
  entry("k3", 16, "I keep circling the same worry about money and work."),
  entry("k4", 24, "I should have spoken up but I keep waiting to quit."),
  entry("k5", 32, "I keep putting off the decision — eventually maybe Monday."),
  entry("k6", 40, "I want to give up and escape — I keep waiting to quit my job."),
  entry("k7", 45, "I keep putting off again and the conflict keeps spiraling at work."),
];
const costCounts = buildCostEvidence(
  costArchive.slice(0, 6).map((e) => e.id),
  costArchive,
);
const costSum = Object.values(costCounts).reduce((s, n) => s + n, 0);
assert.ok(costSum > 0, "cost evidence should count subsequent reflections");
assert.ok(
  costEvidenceRankBoost(costCounts) > costEvidenceRankBoost({
    avoidance: 0,
    delayedDecisions: 0,
    quittingLanguage: 0,
    repeatedConflict: 0,
    emotionalSpirals: 0,
  }),
);
assert.ok(
  costEvidenceRankBoost({
    avoidance: 1,
    delayedDecisions: 0,
    quittingLanguage: 0,
    repeatedConflict: 0,
    emotionalSpirals: 0,
  }) > 0,
);

// Root belief copy stays hedged — no forbidden clinical language
const rootTypes = ["contradiction", "avoidance_signal", "repeated_phrase", "recurring_pattern"];
for (const type of rootTypes) {
  const hypothesis = deriveRootBeliefHypothesis(
    {
      type,
      title: "test",
      detail: "You keep waiting at work",
      evidence: [{ entryId: "e1", phrase: "I keep waiting to quit and avoid conflict" }],
      entryIds: ["e1"],
      scores: { recurrenceCount: 10 },
      specificity: { isWeakOrGeneric: false, specificityScore: 70 },
      sourceKey: "t",
      id: "t",
    },
    ["quitting_escape", "delayed_decision"],
  );
  if (hypothesis) {
    assert.ok(!FORBIDDEN_ROOT_BELIEF.test(hypothesis), `forbidden root belief for ${type}`);
    assert.ok(/\bmay\b/i.test(hypothesis), `hedged root belief for ${type}`);
  }
}

// Cumulative blind spot review — snapshots and since-last-time
const {
  persistBlindSpotReviewSnapshot,
  clearBlindSpotReviewSnapshotsForEval,
  readLatestBlindSpotReviewSnapshot,
} = await import("../lib/blind-spots/blind-spot-review-snapshots.ts");

clearBlindSpotReviewSnapshotsForEval();
if (readyReport.kind === "ready") {
  assert.ok(persistBlindSpotReviewSnapshot(readyReport.review), "snapshot should save");
  assert.ok(readLatestBlindSpotReviewSnapshot()?.reviewId === readyReport.review.reviewId);

  const repeatSame = buildBlindSpotReview(repeating);
  assert.equal(repeatSame.kind, "ready");
  if (repeatSame.kind === "ready") {
    assert.equal(repeatSame.sinceLastTime.hasPriorSnapshot, true);
    assert.equal(repeatSame.sinceLastTime.hasMeaningfulChange, false);
    assert.ok(
      repeatSame.sinceLastTime.noChangeMessage?.includes("No major change"),
      "honest no-change copy",
    );
  }

  const withNewEntry = [
    ...repeating,
    entry(
      "e7",
      32,
      "I finally told my manager the truth — I keep avoiding hard conversations at work.",
    ),
  ];
  const evolved = buildBlindSpotReview(withNewEntry);
  assert.equal(evolved.kind, "ready");
  if (evolved.kind === "ready") {
    assert.ok(
      evolved.sinceLastTime.hasMeaningfulChange,
      "new reflections should produce change lines",
    );
    assert.ok(evolved.sinceLastTime.lines.length > 0);
  }
}

clearBlindSpotReviewSnapshotsForEval();
const freqReady = buildBlindSpotReview(frequencyArchive);
assert.equal(freqReady.kind, "ready");
if (freqReady.kind === "ready") {
  persistBlindSpotReviewSnapshot(freqReady.review);
}
const contraReady = buildBlindSpotReview(contradictionArchive);
assert.equal(contraReady.kind, "ready");
if (contraReady.kind === "ready" && freqReady.kind === "ready") {
  const pickedContradiction =
    contraReady.review.reviewId.includes("contradiction") ||
    contraReady.review.headline !== freqReady.review.headline;
  assert.ok(
    pickedContradiction,
    "higher-scorecard / new-signal insight should beat stale repeated weak pattern",
  );
  assert.ok(contraReady.sinceLastTime.hasPriorSnapshot);
}

const reviewUi = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), "../components/blind-spots/BlindSpotReview.tsx"),
  "utf8",
);
assert.ok(reviewUi.includes("BlindSpotReviewChangesSection"));
assert.ok(reviewUi.includes("BlindSpotExperimentSection"));

// Blind spot experiment layer — restraint and ingredient-specific tests
const {
  buildBlindSpotExperiment,
  shouldShowBlindSpotExperiment,
  FORBIDDEN_EXPERIMENT_COPY,
  passesExperimentCopyGate,
} = await import("../lib/blind-spots/blind-spot-experiment.ts");
const {
  saveBlindSpotExperimentFeedback,
  getBlindSpotExperimentFeedback,
  clearBlindSpotExperimentFeedbackForEval,
} = await import("../lib/blind-spots/blind-spot-experiment-feedback.ts");
const { BLIND_SPOT_PAGE } = await import("../lib/blind-spots/blind-spot-copy.ts");

function baseExperimentFacts(overrides = {}) {
  return {
    reflectionCount: 5,
    spanLabel: "3 weeks",
    spanDays: 21,
    richSpanLabel: "over 3 weeks",
    lifeAreaCount: 1,
    lifeAreas: ["Work"],
    contradictionPresent: false,
    failedPredictionCount: 0,
    costEvidenceCount: 0,
    specificityScore: 70,
    skepticPass: true,
    ...overrides,
  };
}

function baseExperimentInsight(overrides = {}) {
  return {
    type: "recurring_pattern",
    title: "test",
    detail: "",
    evidence: [{ entryId: "e1", phrase: "test" }],
    entryIds: ["e1", "e2", "e3"],
    specificity: { isWeakOrGeneric: false, specificityScore: 70 },
    sourceKey: "k",
    ...overrides,
  };
}

function experimentFixture(overrides = {}) {
  return {
    insight: baseExperimentInsight(overrides.insight),
    signalIds: overrides.signalIds ?? [],
    evidenceStrengthFacts: baseExperimentFacts(overrides.facts),
    failedPredictionLinked: overrides.failedPredictionLinked ?? false,
    evidenceStrength: overrides.evidenceStrength ?? "medium",
    scorecardScore: overrides.scorecardScore ?? 45,
  };
}

assert.equal(shouldShowBlindSpotExperiment({ evidenceStrength: "low", scorecardScore: 30 }), false);
assert.equal(shouldShowBlindSpotExperiment({ evidenceStrength: "low", scorecardScore: 40 }), true);
assert.equal(shouldShowBlindSpotExperiment({ evidenceStrength: "medium", scorecardScore: 10 }), true);

const ingredients = [
  {
    name: "prediction_failure",
    fixture: experimentFixture({
      failedPredictionLinked: true,
      signalIds: ["wrong_prediction"],
      facts: baseExperimentFacts({ failedPredictionCount: 1 }),
    }),
    needle: /prediction/i,
  },
  {
    name: "criticism_rejection",
    fixture: experimentFixture({
      signalIds: ["self_worth_collapse"],
      insight: baseExperimentInsight({
        detail: "They told me I am not good enough after harsh feedback",
      }),
    }),
    needle: /24 hours|feedback/i,
  },
  {
    name: "avoidance_delay",
    fixture: experimentFixture({
      signalIds: ["avoidance", "delayed_decision"],
      insight: baseExperimentInsight({ type: "avoidance_signal" }),
    }),
    needle: /avoided decision|fork/i,
  },
  {
    name: "conflict_spiral",
    fixture: experimentFixture({
      signalIds: ["conflict", "emotional_spiral"],
      insight: baseExperimentInsight({
        detail: "We argued and I spiraled into overwhelm",
      }),
    }),
    needle: /happened|assumed/i,
  },
  {
    name: "cross_life_area",
    fixture: experimentFixture({
      facts: baseExperimentFacts({ lifeAreaCount: 3, lifeAreas: ["Work", "Money", "Family"] }),
    }),
    needle: /another area|cross/i,
  },
];

for (const { name, fixture, needle } of ingredients) {
  const exp = buildBlindSpotExperiment(fixture);
  assert.ok(exp, `${name} should produce an experiment`);
  assert.equal(exp.ingredient, name);
  assert.ok(needle.test(exp.smallThing + exp.tryNextTime + exp.checkWhether));
  const blob = [exp.smallThing, exp.tryNextTime, exp.checkWhether].join(" ");
  assert.ok(!FORBIDDEN_EXPERIMENT_COPY.test(blob), `forbidden experiment copy for ${name}`);
  assert.ok(passesExperimentCopyGate(exp));
  assert.ok(/\btest\b/i.test(blob) || /try this next time/i.test(blob));
  assert.ok(blob.includes("Check whether") || /check whether/i.test(blob));
}

assert.ok(BLIND_SPOT_PAGE.experimentDisclaimer.includes("Not advice"));
assert.ok(!FORBIDDEN_RE.test(BLIND_SPOT_PAGE.experimentDisclaimer));

if (readyReport.kind === "ready") {
  assert.ok(readyReport.review.experiment, "high-confidence ready review should include experiment");
  const expBlob = [
    readyReport.review.experiment.smallThing,
    readyReport.review.experiment.tryNextTime,
    readyReport.review.experiment.checkWhether,
  ].join(" ");
  assert.ok(!FORBIDDEN_EXPERIMENT_COPY.test(expBlob));
}

clearBlindSpotExperimentFeedbackForEval();
if (readyReport.kind === "ready") {
  saveBlindSpotExperimentFeedback({
    reviewId: readyReport.review.reviewId,
    experimentIngredient: readyReport.review.experiment.ingredient,
    rating: "will_try",
  });
  assert.equal(getBlindSpotExperimentFeedback(readyReport.review.reviewId), "will_try");
}

const hidden = buildBlindSpotExperiment(
  experimentFixture({ evidenceStrength: "low", scorecardScore: 12 }),
);
assert.equal(hidden, null);

// Pattern → experiment → follow-up loop
const {
  createExperimentCommitment,
  getDueExperimentFollowUps,
  applyExperimentFeedbackToCommitment,
  isEligibleForExperimentLoop,
  clearExperimentCommitmentsForEval,
  readAllExperimentCommitments,
  writeExperimentCommitments,
  EXPERIMENT_FOLLOW_UP_DAYS,
} = await import("../lib/blind-spots/blind-spot-experiment-commitment.ts");
const { saveExperimentFollowUpAnswer } = await import(
  "../lib/blind-spots/blind-spot-experiment-followup.ts"
);
const { buildBlindSpotExperimentLoopReport } = await import(
  "../lib/blind-spots/blind-spot-experiment-metrics.ts"
);
const {
  readAllBreakthroughEvents,
  clearBreakthroughEventsForEval,
} = await import("../lib/breakthrough/breakthrough-events.ts");

assert.equal(EXPERIMENT_FOLLOW_UP_DAYS, 7);

if (readyReport.kind === "ready") {
  assert.ok(isEligibleForExperimentLoop(readyReport.review));
  clearExperimentCommitmentsForEval();
  clearBreakthroughEventsForEval();

  const commitment = createExperimentCommitment(readyReport.review);
  assert.ok(commitment);
  assert.equal(commitment.reviewId, readyReport.review.reviewId);
  assert.ok(commitment.experimentText.length > 20);
  assert.ok(commitment.dueAt > commitment.createdAt);

  const past = readAllExperimentCommitments();
  past[0].createdAt = new Date(Date.now() - 8 * 86400000).toISOString();
  past[0].dueAt = new Date(Date.now() - 1000).toISOString();
  writeExperimentCommitments(past);
  assert.ok(getDueExperimentFollowUps().length >= 1, "due follow-up after 7 days");

  saveExperimentFollowUpAnswer(past[0].commitmentId, "caught_earlier");
  const events = readAllBreakthroughEvents();
  assert.ok(
    events.some((e) => e.type === "caught_it_earlier" && e.relatedBlindSpotId === commitment.reviewId),
    "caught earlier should create breakthrough event",
  );

  applyExperimentFeedbackToCommitment(readyReport.review, "will_try");
  const loopReport = buildBlindSpotExperimentLoopReport();
  assert.ok(loopReport.commitmentCount >= 1);
  assert.ok(typeof loopReport.commitmentRate === "number" || loopReport.commitmentRate === null);
  assert.ok(loopReport.byIngredient.length === 5);
}

const weakLoop = buildBlindSpotReview(weakThemes);
assert.equal(weakLoop.kind, "empty");
assert.equal(
  shouldShowBlindSpotExperiment({ evidenceStrength: "low", scorecardScore: 12 }),
  false,
);

const discoverSrc = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), "../app/discover/page.tsx"),
  "utf8",
);
assert.ok(discoverSrc.includes("BlindSpotExperimentFollowUpStack"));

const internalSrc = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), "../app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
assert.ok(internalSrc.includes("BlindSpotExperimentLoopPanel"));

console.log("run-blind-spot-tests ok");
