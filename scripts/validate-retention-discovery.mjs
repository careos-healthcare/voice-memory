#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
globalThis.sessionStorage = {
  getItem: (k) => storage.get(`s:${String(k)}`) ?? null,
  setItem: (k, v) => storage.set(`s:${String(k)}`, String(v)),
  removeItem: (k) => storage.delete(`s:${String(k)}`),
  clear: () => {
    for (const key of [...storage.keys()]) {
      if (key.startsWith("s:")) storage.delete(key);
    }
  },
  get length() {
    return [...storage.keys()].filter((k) => k.startsWith("s:")).length;
  },
  key: () => null,
};

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
  clearReturnReasonsForEval,
  saveReturnReason,
  readAllReturnReasons,
  shouldAskReturnReasonThisSession,
  markReturnReasonAskedThisSession,
  RETURN_REASON_OPTIONS,
} = await import("../lib/retention/return-reason-survey.ts");

const {
  clearSessionOutcomesForEval,
  saveSessionOutcome,
  readAllSessionOutcomes,
  helpfulnessScore,
} = await import("../lib/retention/session-outcome.ts");

const {
  clearFirstValueMomentsForEval,
  observeFirstValueMoment,
  readFirstValueSnapshot,
} = await import("../lib/retention/first-value-moments.ts");

const { buildRetentionDiscoveryReport, returnReasonBySessionBucket } = await import(
  "../lib/retention/retention-discovery-report.ts"
);

const { clearBlindSpotFeedbackForEval, saveBlindSpotReaction } = await import(
  "../lib/blind-spots/blind-spot-feedback.ts"
);

clearReturnReasonsForEval();
clearSessionOutcomesForEval();
clearFirstValueMomentsForEval();
clearBlindSpotFeedbackForEval();

// Return reason — once per session
assert.equal(shouldAskReturnReasonThisSession(1), true);
saveReturnReason({ reason: "habit", sessionNumber: 1 });
markReturnReasonAskedThisSession(1);
assert.equal(shouldAskReturnReasonThisSession(1), false);
assert.equal(readAllReturnReasons().length, 1);
assert.equal(RETURN_REASON_OPTIONS.length, 7);

// Session outcome
saveSessionOutcome({ outcome: "yes_clearer", sessionNumber: 1 });
assert.equal(helpfulnessScore("not_really"), 0);
assert.equal(helpfulnessScore("somewhat"), 0.5);
assert.equal(readAllSessionOutcomes().length, 1);

// First value moments — idempotent
const firstVisit = new Date();
firstVisit.setDate(firstVisit.getDate() - 3);
localStorage.setItem("voicememory_first_value_first_visit", firstVisit.toISOString());

observeFirstValueMoment("blind_spot_viewed");
observeFirstValueMoment("blind_spot_viewed");
observeFirstValueMoment("emerging_pattern_viewed");

const fv = readFirstValueSnapshot();
assert.equal(fv.moments.length, 2);
assert.equal(fv.timeToFirstValueKind, "blind_spot_viewed");
assert.equal(fv.timeToFirstValueDays, 3);

// Report with wow correlation
saveReturnReason({ reason: "curious_what_noticed", sessionNumber: 2 });
saveSessionOutcome({ outcome: "yes_differently", sessionNumber: 2 });
saveBlindSpotReaction({
  reviewId: "blind-spot:test:signal",
  reaction: "uncomfortably_accurate",
  headline: "Test",
  evidenceStrength: "high",
  estimatedImpactScore: 70,
  reflectionCount: 8,
  archiveAgeDays: 14,
});

const report = buildRetentionDiscoveryReport();
assert.ok(report.returnReasons.length >= 2);
assert.ok(report.insights.length >= 4);
assert.ok(report.signalScore.averageWowScore > 0);
assert.ok(report.mostCommonReturnReason);

const buckets = returnReasonBySessionBucket();
assert.ok(Array.isArray(buckets.session_1));

// Required files
const required = [
  "types/retention-discovery.ts",
  "lib/retention/return-reason-survey.ts",
  "lib/retention/session-outcome.ts",
  "lib/retention/first-value-moments.ts",
  "lib/retention/retention-discovery-report.ts",
  "components/retention/ReturnReasonPrompt.tsx",
  "components/retention/SessionOutcomePrompt.tsx",
  "components/retention/RetentionInstrumentation.tsx",
  "app/internal/retention-discovery/page.tsx",
  "components/internal/RetentionDiscoveryPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const providers = fs.readFileSync(path.join(ROOT, "app/providers.tsx"), "utf8");
if (!providers.includes("RetentionInstrumentation")) {
  failures.push("app/providers.tsx must mount RetentionInstrumentation");
}

const pageSrc = fs.readFileSync(
  path.join(ROOT, "app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!pageSrc.includes("buildRetentionDiscoveryReport")) {
  failures.push("retention-discovery page must build report");
}

if (failures.length > 0) {
  console.error("validate-retention-discovery failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-retention-discovery ok");
