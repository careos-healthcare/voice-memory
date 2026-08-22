#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
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

const {
  saveBreakthroughEvent,
  readAllBreakthroughEvents,
  clearBreakthroughEventsForEval,
} = await import("../../packages/shared/lib/breakthrough/breakthrough-events.ts");
const {
  resolveBreakthroughType,
  BREAKTHROUGH_PROMPTS,
} = await import("../../packages/shared/lib/breakthrough/breakthrough-copy.ts");
const {
  insightProfileFromBlindSpotReview,
  buildBlindSpotAttribution,
} = await import("../../packages/shared/lib/breakthrough/breakthrough-attribution.ts");
const { buildBreakthroughTrackingReport } = await import(
  "../../packages/shared/lib/breakthrough/breakthrough-tracking-report.ts"
);
const {
  shouldOfferBreakthroughPrompt,
  recordBreakthroughEligibleSurface,
  clearBreakthroughPromptGateForEval,
} = await import("../../packages/shared/lib/breakthrough/breakthrough-prompt-gate.ts");
const { saveBlindSpotReaction, clearBlindSpotFeedbackForEval } = await import(
  "../../packages/shared/lib/blind-spots/blind-spot-feedback.ts"
);
const { saveTheoryFeedback, clearTheoryFeedbackForEval } = await import(
  "../../packages/shared/lib/theories/theory-feedback.ts"
);
const {
  recordNotificationOpened,
  clearNotificationLifecycleForEval,
} = await import("../../packages/shared/lib/theories/theory-notification-lifecycle.ts");
const { appendTheoryEventForEval, clearTheoryEventsForEval, THEORY_EVENTS } =
  await import("../../packages/shared/lib/theories/theory-events.ts");

clearBreakthroughEventsForEval();
clearBreakthroughPromptGateForEval();
clearBlindSpotFeedbackForEval();
clearTheoryFeedbackForEval();
clearNotificationLifecycleForEval();
clearTheoryEventsForEval();

assert.equal(resolveBreakthroughType("noticed_pattern", "yes"), "noticed_pattern");
assert.equal(resolveBreakthroughType("theory_right", "no"), "theory_no_longer_fits");
assert.ok(BREAKTHROUGH_PROMPTS.length >= 3, "expected prompt copy");

const mockReview = {
  reviewId: "review-test-1",
  headline: "You keep waiting to start",
  evidenceStrengthFacts: {
    reflectionCount: 6,
    spanLabel: "3 months",
    spanDays: 45,
    richSpanLabel: "3 months",
    lifeAreaCount: 2,
    lifeAreas: ["work", "money"],
    contradictionPresent: true,
    failedPredictionCount: 1,
    costEvidenceCount: 2,
    specificityScore: 70,
    skepticPass: true,
  },
  contradictionNote: "One reflection disagrees",
  predictionEvidenceNote: "Prediction missed",
  costEvidenceLines: ["Cost line"],
  linkedAreas: ["work", "money"],
};

const profile = insightProfileFromBlindSpotReview(mockReview);
assert.equal(profile.hasContradiction, true);
assert.equal(profile.hasPredictionFailure, true);
assert.equal(profile.hasCostEvidence, true);
assert.equal(profile.hasCrossLifeArea, true);
assert.equal(profile.hasLongTimeSpan, true);

appendTheoryEventForEval(THEORY_EVENTS.discoverOpened, { theoryId: "t1" });
recordNotificationOpened({
  id: "n1",
  theoryId: "t1",
  type: "strengthened",
  title: "Theory strengthened",
  body: "Body",
  createdAt: new Date().toISOString(),
});

const attribution = buildBlindSpotAttribution(mockReview);
assert.ok(attribution.relatedBlindSpotId === "review-test-1");
assert.ok(attribution.relatedNotificationId === "n1");
assert.ok(attribution.lastDiscoverVisitAt);

saveBreakthroughEvent({
  type: "behavior_changed",
  answer: "yes",
  promptId: "insight_changed",
  relatedBlindSpotId: mockReview.reviewId,
  attribution,
});
saveBreakthroughEvent({
  type: "theory_no_longer_fits",
  answer: "no",
  promptId: "theory_right",
  relatedTheoryId: "t1",
  attribution: { ...attribution, relatedTheoryId: "t1" },
});

assert.equal(readAllBreakthroughEvents().length, 2);

saveBlindSpotReaction({
  reviewId: "r1",
  reaction: "surprising",
  headline: "h",
  evidenceStrength: "high",
  estimatedImpactScore: 80,
  reflectionCount: 5,
  archiveAgeDays: 30,
});
saveTheoryFeedback({
  theoryId: "t1",
  reaction: "surprising",
  statement: "You avoid hard talks",
  source: "pattern",
  confidence: 60,
});

const report = buildBreakthroughTrackingReport();
assert.equal(report.totalBreakthroughs, 1);
assert.ok(report.breakthroughRate === 50, `rate ${report.breakthroughRate}`);
assert.ok(report.breakthroughsPer100Insights !== null);
assert.ok(report.insightDimensions.length === 5);
assert.equal(report.winningInsightTitle, "What kinds of insights lead to behavior change?");
assert.ok(report.byTheoryType.some((r) => r.theoryType === "strengthened"));

for (let i = 0; i < 4; i++) recordBreakthroughEligibleSurface();
if (!shouldOfferBreakthroughPrompt()) {
  fail("gate should allow prompt on 4th eligible surface");
}

const panelPath = path.join(ROOT, "apps/web/components/internal/BreakthroughTrackingPanel.tsx");
const pagePath = path.join(ROOT, "apps/web/app/internal/blind-spot-discovery/page.tsx");
const reviewPath = path.join(ROOT, "apps/web/components/blind-spots/BlindSpotReview.tsx");
if (!fs.existsSync(panelPath)) fail("BreakthroughTrackingPanel missing");
const pageSrc = fs.readFileSync(pagePath, "utf8");
if (!pageSrc.includes("BreakthroughTrackingPanel")) {
  fail("blind-spot-discovery must render BreakthroughTrackingPanel");
}
const reviewSrc = fs.readFileSync(reviewPath, "utf8");
if (!reviewSrc.includes("BlindSpotBreakthroughPrompt")) {
  fail("BlindSpotReview must wire BlindSpotBreakthroughPrompt");
}
const panelSrc = fs.readFileSync(panelPath, "utf8");
for (const needle of ["Breakthrough rate", "Per 100 insights", "winningInsightTitle"]) {
  if (!panelSrc.includes(needle)) fail(`panel missing: ${needle}`);
}

if (failures.length > 0) {
  console.error("validate-breakthrough-tracking failed:\n", failures.join("\n"));
  process.exit(1);
}

const {
  createExperimentCommitment,
  clearExperimentCommitmentsForEval,
  readAllExperimentCommitments,
  writeExperimentCommitments,
  getDueExperimentFollowUps,
} = await import("../../packages/shared/lib/blind-spots/blind-spot-experiment-commitment.ts");
const { saveExperimentFollowUpAnswer } = await import(
  "../../packages/shared/lib/blind-spots/blind-spot-experiment-followup.ts"
);

clearExperimentCommitmentsForEval();
const expReview = {
  ...mockReview,
  reviewId: "blind-spot:contradiction:test-exp",
  experiment: {
    ingredient: "prediction_failure",
    smallThing: "Write the prediction down.",
    tryNextTime: "Try this next time.",
    checkWhether: "Check whether it matched.",
  },
  evidenceStrength: "high",
  scorecard: { score: 55, dimensions: [], summary: "" },
  linkedAreas: ["Work", "Money"],
  costEvidenceLines: ["line"],
  contradictionNote: "note",
  predictionEvidenceNote: "pred",
  possibleBelief: "may",
  pattern: "may",
  observation: "may",
  likelyCost: "may",
  evidenceQuotes: [{ entryId: "e1", dateLabel: "Jan 1", quote: "test" }],
  alternativeToTest: "test",
  ifThisDisappeared: "test",
  whyThisMatters: "test",
  disclaimer: "test",
  reflectionCount: 6,
  archiveEntryIds: ["e1"],
  estimatedImpactScore: 80,
  generatedAt: new Date().toISOString(),
  specificityScore: 70,
};

const created = createExperimentCommitment(expReview);
assert.ok(created);
const stored = readAllExperimentCommitments();
stored[0].dueAt = new Date(Date.now() - 60_000).toISOString();
writeExperimentCommitments(stored);
assert.ok(getDueExperimentFollowUps().length >= 1);

const before = readAllBreakthroughEvents().length;
saveExperimentFollowUpAnswer(stored[0].commitmentId, "caught_earlier");
const after = readAllBreakthroughEvents();
assert.ok(after.length > before);
assert.ok(after.some((e) => e.type === "caught_it_earlier"));

const second = createExperimentCommitment({
  ...expReview,
  reviewId: "blind-spot:contradiction:test-exp-2",
});
assert.ok(second);
saveExperimentFollowUpAnswer(second.commitmentId, "after_the_fact");
assert.ok(
  readAllBreakthroughEvents().some((e) => e.type === "noticed_pattern"),
);

if (!pageSrc.includes("BlindSpotExperimentLoopPanel")) {
  fail("blind-spot-discovery must render BlindSpotExperimentLoopPanel");
}

console.log("validate-breakthrough-tracking ok");
