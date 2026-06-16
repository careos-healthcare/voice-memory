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

const {
  clearBlindSpotFeedbackForEval,
  getBlindSpotReaction,
  readAllBlindSpotFeedback,
  saveBlindSpotReaction,
} = await import("../lib/blind-spots/blind-spot-feedback.ts");

const { buildBlindSpotValidationReport, computeBlindSpotMetrics } = await import(
  "../lib/blind-spots/blind-spot-metrics.ts"
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

const dashboardPage = path.join(ROOT, "app/internal/blind-spot-performance/page.tsx");
const panel = path.join(ROOT, "components/internal/BlindSpotPerformancePanel.tsx");
if (!fs.existsSync(dashboardPage)) {
  failures.push("missing dashboard page");
}
if (!fs.existsSync(panel)) {
  failures.push("missing dashboard panel");
}
const pageSrc = fs.readFileSync(dashboardPage, "utf8");
if (!pageSrc.includes("BlindSpotPerformancePanel")) {
  failures.push("dashboard page must render BlindSpotPerformancePanel");
}
if (!pageSrc.includes("buildBlindSpotValidationReport")) {
  failures.push("dashboard page must build validation report");
}

const reviewSrc = fs.readFileSync(
  path.join(ROOT, "components/blind-spots/BlindSpotReview.tsx"),
  "utf8",
);
if (!reviewSrc.includes("uncomfortably_accurate") || reviewSrc.includes("not_accurate")) {
  failures.push("BlindSpotReview must use new reaction model");
}

console.log(
  JSON.stringify(
    {
      metrics,
      topPerforming: report.topPerforming.slice(0, 2),
      worstPerforming: report.worstPerforming.slice(0, 2),
      evidenceStrengthCorrelation: report.evidenceStrengthCorrelation,
    },
    null,
    2,
  ),
);

if (failures.length > 0) {
  console.error("validate-blind-spot-feedback failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-blind-spot-feedback ok");
