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
globalThis.window = globalThis;
globalThis.window.location = { pathname: "/" };
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

const FORBIDDEN =
  /\b(diagnos|disorder|patholog|clinical|therapy|counsel|coach|treatment|mental health|you are|you're always|root cause|guaranteed|certainly)\b/i;

const {
  insightOutcomeEventFromBlindSpotReview,
  profileKeyForEvent,
} = await import("../packages/shared/lib/insights/insight-outcome-attribution.ts");
const {
  scheduleInsightOutcomeOffer,
  saveInsightOutcomeResponse,
  canShowInsightOutcomePrompt,
  markInsightOutcomePromptShown,
  clearInsightOutcomeForEval,
  readInsightOutcomeEventsWithResponse,
  OUTCOME_PROMPT_COOLDOWN_MS,
} = await import("../packages/shared/lib/insights/insight-outcome-storage.ts");
const { buildInsightOutcomeReport } = await import("../packages/shared/lib/insights/insight-outcome-report.ts");
const { INSIGHT_OUTCOME_COPY } = await import("../packages/shared/lib/insights/insight-outcome-copy.ts");

const mockReview = {
  reviewId: "blind-spot:contradiction:test",
  headline: "One possible pattern",
  observation: "Your words may suggest a thread",
  possibleBelief: "Your words suggest tension",
  pattern: "This may be forming",
  costEvidence: {},
  costEvidenceLines: [],
  likelyCost: "This may cost energy",
  evidenceQuotes: [{ entryId: "e1", dateLabel: "Jan 1", quote: "test" }],
  evidenceStrength: "high",
  evidenceStrengthFacts: {
    reflectionCount: 5,
    spanLabel: "3 weeks",
    spanDays: 45,
    richSpanLabel: "3 weeks",
    lifeAreaCount: 2,
    lifeAreas: ["Work", "Money"],
    contradictionPresent: true,
    failedPredictionCount: 0,
    costEvidenceCount: 2,
    specificityScore: 70,
    skepticPass: true,
  },
  linkedAreas: ["Work", "Money"],
  alternativeToTest: "One alternative",
  ifThisDisappeared: "If softened",
  whyThisMatters: "Why",
  disclaimer: "hypothesis",
  reflectionCount: 5,
  archiveEntryIds: ["e1"],
  estimatedImpactScore: 80,
  generatedAt: new Date().toISOString(),
  specificityScore: 70,
  scorecard: { score: 55, dimensions: [], summary: "" },
};

clearInsightOutcomeForEval();
assert.ok(canShowInsightOutcomePrompt());

const draft = insightOutcomeEventFromBlindSpotReview(mockReview);
const scheduled = scheduleInsightOutcomeOffer(draft, "experiment_followup");
assert.ok(scheduled, "should schedule offer");

const saved = saveInsightOutcomeResponse("acted_differently");
assert.ok(saved);
assert.equal(saved.outcome, "acted_differently");
assert.equal(saved.insightType, "blind_spot");
assert.equal(saved.contradictionPresent, true);
assert.ok(saved.respondedAt);

assert.ok(!canShowInsightOutcomePrompt(), "14-day cooldown after show");
const lastShown = storage.get("voicememory_insight_outcome_last_shown");
assert.ok(lastShown);
const elapsed = Date.now() - new Date(lastShown).getTime();
markInsightOutcomePromptShown();
storage.set(
  "voicememory_insight_outcome_last_shown",
  new Date(Date.now() - OUTCOME_PROMPT_COOLDOWN_MS - 1000).toISOString(),
);
assert.ok(canShowInsightOutcomePrompt(), "cooldown expires after 14 days");

clearInsightOutcomeForEval();
scheduleInsightOutcomeOffer(draft, "breakthrough_followup");
saveInsightOutcomeResponse("problem_improved");
storage.delete("voicememory_insight_outcome_last_shown");
scheduleInsightOutcomeOffer(
  { ...draft, insightId: "blind-spot:2", contradictionPresent: false, costEvidencePresent: true },
  "theory_revisit",
);
saveInsightOutcomeResponse("noticed_pattern");

const report = buildInsightOutcomeReport();
assert.equal(report.totalResponses, 2);
assert.ok((report.overallOutcomeRate ?? 0) >= 50);
assert.ok((report.problemImprovedRate ?? 0) > 0);
assert.ok((report.noticedPatternRate ?? 0) > 0);
assert.ok(
  readInsightOutcomeEventsWithResponse().some((e) => e.outcome === "problem_improved"),
);
assert.ok(
  readInsightOutcomeEventsWithResponse().some((e) => e.outcome === "noticed_pattern"),
);
assert.ok(report.byIngredient.some((r) => r.ingredient === "contradiction"));
assert.ok(report.topProfiles.length >= 1);
assert.ok(report.weakestProfiles.length >= 1);

const key = profileKeyForEvent(saved);
assert.ok(key.includes("blind_spot"));

assert.ok(INSIGHT_OUTCOME_COPY.question.includes("What happened"));
assert.ok(!FORBIDDEN.test(INSIGHT_OUTCOME_COPY.question));

const discoverySrc = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/blind-spot-discovery/page.tsx"),
  "utf8",
);
if (!discoverySrc.includes("InsightOutcomePanel")) {
  fail("blind-spot-discovery must wire InsightOutcomePanel");
}
const panelSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/components/internal/InsightOutcomePanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("Behavior Change Outcomes")) {
  fail("InsightOutcomePanel must include Behavior Change Outcomes title");
}

for (const rel of [
  "apps/web/components/insights/InsightOutcomePrompt.tsx",
  "packages/shared/lib/insights/insight-outcome-report.ts",
  "packages/shared/types/insight-outcome.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const reviewSrc = fs.readFileSync(path.join(ROOT, "apps/web/components/blind-spots/BlindSpotReview.tsx"), "utf8");
if (!reviewSrc.includes("InsightOutcomePromptStack")) {
  fail("BlindSpotReview must wire outcome prompt");
}

if (failures.length > 0) {
  console.error("validate-insight-outcomes failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-insight-outcomes ok");
