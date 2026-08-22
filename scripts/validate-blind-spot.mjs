#!/usr/bin/env node
/**
 * Unified blind-spot validation — combines 5 former scripts.
 * Run all: npm run validate:blind-spot
 * Run one:  BLIND_SPOT_CHECK=tests npm run validate:blind-spot
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { deferRetiredWebSurface, readOrDefer } from "./lib/retired-web-surface.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function formatViolation(v) {
  const filePath = v.filePath ?? v.file;
  const lineNo = v.lineNo ?? (typeof v.line === "number" ? v.line : 0);
  if (filePath && typeof filePath === "string") {
    const rel = path.relative(ROOT, filePath);
    const loc = lineNo > 0 ? `${rel}:${lineNo}` : rel;
    const label = v.label ?? v.word ?? v.rule ?? "violation";
    const text = v.text ?? (typeof v.line === "string" ? v.line : "") ?? v.detail ?? "";
    return `${loc} [${label}] ${text}`.trim();
  }
  return String(v);
}

const CHECKS = [
  { name: "tests", run: checkTests },
  { name: "feedback", run: checkFeedback },
  { name: "acceleration", run: checkAcceleration },
  { name: "discovery", run: checkDiscovery },
  { name: "quality", run: checkQuality },
];

async function main() {
  const only = process.env.BLIND_SPOT_CHECK?.trim();
  const selected = only ? CHECKS.filter((c) => c.name === only) : CHECKS;
  if (only && selected.length === 0) {
    console.error(`Unknown BLIND_SPOT_CHECK="${only}". Valid: ${CHECKS.map((c) => c.name).join(", ")}`);
    process.exit(1);
  }

  let failed = false;
  for (const check of selected) {
    const failures = await check.run();
    if (failures.length > 0) {
      failed = true;
      console.error(`\n[${check.name}] failed — ${failures.length} issue(s):`);
      for (const f of failures.slice(0, 40)) console.error(`  ${f}`);
      if (failures.length > 40) console.error(`  … and ${failures.length - 40} more`);
    } else {
      console.log(`[${check.name}] passed`);
    }
  }

  if (failed) {
    console.error("\nvalidate:blind-spot failed");
    process.exit(1);
  }
  console.log(`validate:blind-spot passed (${selected.length} check(s))`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function checkTests() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const {buildCostEvidence} = await import("../packages/shared/lib/blind-spots/cost-evidence.ts");
    const {buildBlindSpotReview} = await import("../packages/shared/lib/blind-spots/blind-spot-review.ts");
    const {BLIND_SPOT_EMPTY_MESSAGE,
      BLIND_SPOT_WEAK_EVIDENCE_MESSAGE,} = await import("../packages/shared/lib/blind-spots/blind-spot-copy.ts");
    const {contradictionRankBoost,
      costEvidenceRankBoost,
      deriveRootBeliefHypothesis,
      failedPredictionRankBoost,
      FORBIDDEN_ROOT_BELIEF,
      passesSkepticEvidenceGate,} = await import("../packages/shared/lib/blind-spots/evidence-accuracy.ts");
    const {computeEvidenceStrength,
      rankBlindSpotCandidates,} = await import("../packages/shared/lib/blind-spots/blind-spot-ranking.ts");
    const {buildPredictionReview} = await import("../packages/shared/lib/blind-spots/prediction-review.ts");
    const {syncPredictionCandidates} = await import("../packages/shared/lib/blind-spots/prediction-detection.ts");
    const {buildPatternEngineReport} = await import("../packages/shared/lib/patterns/pattern-engine.ts");

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
    } = await import("../packages/shared/lib/blind-spots/blind-spot-review-snapshots.ts");

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

    const reviewUi = readOrDefer("apps/web/components/blind-spots/BlindSpotReview.tsx", fail);
    if (reviewUi !== null) {
      assert.ok(reviewUi.includes("BlindSpotReviewChangesSection"));
      assert.ok(reviewUi.includes("BlindSpotExperimentSection"));
    }

    // Blind spot experiment layer — restraint and ingredient-specific tests
    const {
      buildBlindSpotExperiment,
      shouldShowBlindSpotExperiment,
      FORBIDDEN_EXPERIMENT_COPY,
      passesExperimentCopyGate,
    } = await import("../packages/shared/lib/blind-spots/blind-spot-experiment.ts");
    const {
      saveBlindSpotExperimentFeedback,
      getBlindSpotExperimentFeedback,
      clearBlindSpotExperimentFeedbackForEval,
    } = await import("../packages/shared/lib/blind-spots/blind-spot-experiment-feedback.ts");
    const { BLIND_SPOT_PAGE } = await import("../packages/shared/lib/blind-spots/blind-spot-copy.ts");

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
    } = await import("../packages/shared/lib/blind-spots/blind-spot-experiment-commitment.ts");
    const { saveExperimentFollowUpAnswer } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-experiment-followup.ts"
    );
    const { buildBlindSpotExperimentLoopReport } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-experiment-metrics.ts"
    );
    const {
      readAllBreakthroughEvents,
      clearBreakthroughEventsForEval,
    } = await import("../packages/shared/lib/breakthrough/breakthrough-events.ts");

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

    const discoverSrc = readOrDefer("apps/web/app/discover/page.tsx", fail);
    if (discoverSrc !== null) {
      assert.ok(discoverSrc.includes("BlindSpotExperimentFollowUpStack"));
    }

    const internalSrc = readOrDefer("apps/web/app/internal/blind-spot-discovery/page.tsx", fail);
    if (internalSrc !== null) {
      assert.ok(internalSrc.includes("BlindSpotExperimentLoopPanel"));
    }
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkFeedback() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
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
      clearBlindSpotFeedbackForEval,
      getBlindSpotReaction,
      readAllBlindSpotFeedback,
      saveBlindSpotReaction,
    } = await import("../packages/shared/lib/blind-spots/blind-spot-feedback.ts");

    const { buildBlindSpotValidationReport, computeBlindSpotMetrics } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-metrics.ts"
    );

    clearBlindSpotFeedbackForEval();

    const reactionBase = {
      reflectionCount: 6,
      archiveAgeDays: 14,
    };

    saveBlindSpotReaction({
      ...reactionBase,
      reviewId: "blind-spot:test:avoid",
      reaction: "surprising",
      headline: "One possible pattern: circling without naming",
      evidenceStrength: "high",
      estimatedImpactScore: 72,
      comment: "Felt new",
    });

    saveBlindSpotReaction({
      ...reactionBase,
      reviewId: "blind-spot:test:avoid",
      reaction: "uncomfortably_accurate",
      headline: "One possible pattern: circling without naming",
      evidenceStrength: "high",
      estimatedImpactScore: 72,
    });

    saveBlindSpotReaction({
      ...reactionBase,
      reviewId: "blind-spot:test:phrase",
      reaction: "obvious",
      headline: "One possible pattern: returning to “I keep”",
      evidenceStrength: "medium",
      estimatedImpactScore: 48,
    });

    saveBlindSpotReaction({
      ...reactionBase,
      reviewId: "blind-spot:test:phrase",
      reaction: "completely_wrong",
      headline: "One possible pattern: returning to “I keep”",
      evidenceStrength: "medium",
      estimatedImpactScore: 48,
    });

    const all = readAllBlindSpotFeedback();
    if (all.length !== 4) {
      failures.push(`expected 4 feedback records, got ${all.length}`);
    }

    if (getBlindSpotReaction("blind-spot:test:avoid") !== "uncomfortably_accurate") {
      failures.push("latest reaction per reviewId should win");
    }

    const withComment = all.find((r) => r.comment === "Felt new");
    if (!withComment) {
      failures.push("comment should persist on saved record");
    }

    const metrics = computeBlindSpotMetrics(all);
    assert.equal(metrics.totalReviews, 4);
    assert.equal(metrics.selfRecognitionScore, 2);
    assert.equal(metrics.holyShitScore, 1);
    assert.equal(metrics.failureScore, 2);

    if (metrics.surprisingRate !== 0.25) {
      failures.push(`unexpected surprising rate: ${metrics.surprisingRate}`);
    }

    const report = buildBlindSpotValidationReport(all);
    if (report.topPerforming[0]?.reviewId !== "blind-spot:test:avoid") {
      failures.push("top performer should be highest self-recognition blind spot");
    }
    if (report.worstPerforming[0]?.failureCount < 1) {
      failures.push("worst performer should have failure signal");
    }
    if (report.evidenceStrengthCorrelation.length < 2) {
      failures.push("evidence strength correlation should span multiple buckets");
    }

    const push = (m) => failures.push(m);

    deferRetiredWebSurface("apps/web/components/internal/BlindSpotPerformancePanel.tsx", push);

    const pageSrc = readOrDefer("apps/web/app/internal/blind-spot-performance/page.tsx", push);
    if (pageSrc !== null) {
      if (!pageSrc.includes("BlindSpotPerformancePanel")) {
        failures.push("dashboard page must render BlindSpotPerformancePanel");
      }
      if (!pageSrc.includes("buildBlindSpotValidationReport")) {
        failures.push("dashboard page must build validation report");
      }
    }

    const reviewSrc = readOrDefer("apps/web/components/blind-spots/BlindSpotReview.tsx", push);
    if (reviewSrc !== null) {
      if (!reviewSrc.includes("uncomfortably_accurate") || reviewSrc.includes("not_accurate")) {
        failures.push("BlindSpotReview must use new reaction model");
      }
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkAcceleration() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
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
      await import("../packages/shared/lib/blind-spots/prediction-detection.ts");
    const { buildEmergingPatterns } = await import("../packages/shared/lib/blind-spots/emerging-patterns.ts");
    const { buildCostEvidence } = await import("../packages/shared/lib/blind-spots/cost-evidence.ts");
    const { buildPredictionReview, buildPredictionAccuracySummary } = await import(
      "../packages/shared/lib/blind-spots/prediction-review.ts"
    );
    const { buildBlindSpotAccelerationReport } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-acceleration.ts"
    );
    const { BLIND_SPOT_EVIDENCE_FIRST_SECTIONS } = await import(
      "../packages/shared/types/blind-spot-acceleration.ts"
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

    const reviewSrc = readOrDefer("apps/web/components/blind-spots/BlindSpotReview.tsx", fail);
    if (reviewSrc !== null) {
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
    }

    const pageSrc = readOrDefer("apps/web/app/blind-spots/page.tsx", fail);
    if (pageSrc !== null) {
      assert.ok(pageSrc.includes("BlindSpotAccelerationView"));
      assert.ok(pageSrc.includes("PredictionReviewSection") === false);
    }

    const accelerationView = readOrDefer(
      "apps/web/components/blind-spots/BlindSpotAccelerationView.tsx",
      fail,
    );
    if (accelerationView !== null) {
      assert.ok(accelerationView.includes("PredictionReviewSection"));
    }
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkDiscovery() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
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
      "../packages/shared/lib/blind-spots/blind-spot-events.ts"
    );
    const { wowMomentScoreForReaction, sumWowMomentScore } = await import(
      "../packages/shared/lib/blind-spots/wow-moment-score.ts"
    );
    const {
      clearBlindSpotFeedbackForEval,
      saveBlindSpotReaction,
      readAllBlindSpotFeedback,
    } = await import("../packages/shared/lib/blind-spots/blind-spot-feedback.ts");
    const {
      clearDelayedValidationsForEval,
      scheduleDelayedValidation,
      getDueDelayedValidations,
      saveDelayedValidationResponse,
    } = await import("../packages/shared/lib/blind-spots/delayed-validation.ts");
    const {
      clearBreakthroughCapturesForEval,
      saveBreakthroughCapture,
      readAllBreakthroughCaptures,
    } = await import("../packages/shared/lib/blind-spots/breakthrough-capture.ts");
    const { buildSelfRecognitionAnalysis } = await import(
      "../packages/shared/lib/blind-spots/self-recognition-analysis.ts"
    );
    const { buildEmergingPatterns } = await import("../packages/shared/lib/blind-spots/emerging-patterns.ts");
    const { BLIND_SPOT_EVIDENCE_FIRST_SECTIONS } = await import(
      "../packages/shared/types/blind-spot-acceleration.ts"
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

    const reviewSrc = readOrDefer("apps/web/components/blind-spots/BlindSpotReview.tsx", (m) =>
      failures.push(m),
    );
    if (reviewSrc !== null) {
      if (!reviewSrc.includes("BreakthroughCapturePrompt") || !reviewSrc.includes("DelayedValidationPrompt")) {
        failures.push("BlindSpotReview must include breakthrough and delayed validation");
      }
    }
    if (!fs.existsSync(path.join(ROOT, "apps/web/app/internal/blind-spot-discovery/page.tsx"))) {
      deferRetiredWebSurface("apps/web/app/internal/blind-spot-discovery/page.tsx", (m) =>
        failures.push(m),
      );
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkQuality() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
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
      "packages/shared/types/blind-spot-quality.ts",
      "packages/shared/lib/blind-spots/blind-spot-quality-storage.ts",
      "packages/shared/lib/blind-spots/blind-spot-quality-score.ts",
      "packages/shared/lib/blind-spots/blind-spot-quality-enrichment.ts",
      "packages/shared/lib/blind-spots/blind-spot-quality-report.ts",
      "apps/web/components/internal/BlindSpotQualityPanel.tsx",
    ];

    for (const rel of required) {
      if (fs.existsSync(path.join(ROOT, rel))) continue;
      if (rel.startsWith("apps/web/")) {
        deferRetiredWebSurface(rel, fail);
        continue;
      }
      fail(`missing ${rel}`);
    }

    const { computeBlindSpotQualityScore, hasAnyQualityOutcome } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-quality-score.ts"
    );
    const {
      appendBlindSpotQualityRecordForEval,
      blindSpotIdFromReviewId,
      clearBlindSpotQualityRecordsForEval,
      persistBlindSpotQualityFromReview,
      readAllBlindSpotQualityRecords,
    } = await import("../packages/shared/lib/blind-spots/blind-spot-quality-storage.ts");
    const { enrichBlindSpotQualityRecord } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-quality-enrichment.ts"
    );
    const { buildBlindSpotQualityReport } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-quality-report.ts"
    );
    const { saveBlindSpotReaction, clearBlindSpotFeedbackForEval } = await import(
      "../packages/shared/lib/blind-spots/blind-spot-feedback.ts"
    );
    const { saveBreakthroughCapture, clearBreakthroughCapturesForEval } = await import(
      "../packages/shared/lib/blind-spots/breakthrough-capture.ts"
    );
    const {
      scheduleInsightOutcomeOffer,
      saveInsightOutcomeResponse,
      clearInsightOutcomeForEval,
    } = await import("../packages/shared/lib/insights/insight-outcome-storage.ts");
    const { buildBlindSpotReview } = await import("../packages/shared/lib/blind-spots/blind-spot-review.ts");
    const { persistBlindSpotReviewSnapshot, clearBlindSpotReviewSnapshotsForEval } =
      await import("../packages/shared/lib/blind-spots/blind-spot-review-snapshots.ts");

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
      path.join(ROOT, "packages/shared/lib/blind-spots/blind-spot-review-snapshots.ts"),
      "utf8",
    );
    if (!snapshotSrc.includes("persistBlindSpotQualityFromReview")) {
      fail("snapshots must persist quality records on save");
    }

    const discoverySrc = readOrDefer("apps/web/app/internal/blind-spot-discovery/page.tsx", fail);
    if (discoverySrc !== null && !discoverySrc.includes("BlindSpotQualityPanel")) {
      fail("blind-spot-discovery must wire BlindSpotQualityPanel");
    }
    const panelSrc = readOrDefer("apps/web/components/internal/BlindSpotQualityPanel.tsx", fail);
    if (panelSrc !== null && !panelSrc.includes("What creates the strongest blind spots")) {
      fail("BlindSpotQualityPanel must include title");
    }

    const scoreSrc = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/blind-spots/blind-spot-quality-score.ts"),
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


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}