#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "types/return-trigger-attribution.ts",
  "lib/retention/return-trigger-attribution-copy.ts",
  "lib/retention/return-trigger-attribution.ts",
  "lib/metrics/return-trigger-attribution-events.ts",
  "lib/internal/return-trigger-attribution-report.ts",
  "components/retention/ReturnTriggerReasonPrompt.tsx",
  "components/retention/ReturnExpectationMetPrompt.tsx",
  "components/internal/ReturnTriggerPanel.tsx",
  "app/internal/return-trigger-attribution/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "lib/retention/return-trigger-attribution-copy.ts"),
  "utf8",
);
for (const phrase of [
  "What were you hoping to check?",
  "Whether my archive changed its view",
  "Did you find what you were looking for?",
  "Just curious",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const events = fs.readFileSync(
  path.join(ROOT, "lib/metrics/return-trigger-attribution-events.ts"),
  "utf8",
);
for (const name of ["return_trigger_reason", "return_expectation_met"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const reasonPrompt = fs.readFileSync(
  path.join(ROOT, "components/retention/ReturnTriggerReasonPrompt.tsx"),
  "utf8",
);
if (!reasonPrompt.includes("saveReturnTriggerReason")) fail("reason prompt must save");
if (!reasonPrompt.includes('data-testid="return-trigger-reason-prompt"')) {
  fail("reason prompt test id");
}

const expectationPrompt = fs.readFileSync(
  path.join(ROOT, "components/retention/ReturnExpectationMetPrompt.tsx"),
  "utf8",
);
if (!expectationPrompt.includes("saveReturnExpectationMet")) fail("expectation prompt must save");
if (!expectationPrompt.includes('data-testid="return-expectation-met-prompt"')) {
  fail("expectation prompt test id");
}

const panel = fs.readFileSync(
  path.join(ROOT, "components/internal/ReturnTriggerPanel.tsx"),
  "utf8",
);
if (!panel.includes("criticalQuestion")) fail("panel must render criticalQuestion");
if (!fs.readFileSync(path.join(ROOT, "lib/internal/return-trigger-attribution-report.ts"), "utf8").includes(
  "Why do people actually come back?",
)) {
  fail("report must answer critical question");
}

const engine = fs.readFileSync(
  path.join(ROOT, "lib/retention/return-trigger-attribution.ts"),
  "utf8",
);
if (!engine.includes("MIN_RETURN_ATTRIBUTION_HOURS = 24")) {
  fail("must use 24h return threshold");
}

for (const rel of ["app/page.tsx", "app/discover/page.tsx", "components/discover/TheoryChangeFeed.tsx"]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (rel.includes("page.tsx") && rel.includes("discover") && !src.includes("ReturnExpectationMetPrompt")) {
    fail("discover page must render expectation prompt");
  }
  if (rel === "app/page.tsx" && !src.includes("ReturnTriggerReasonPrompt")) {
    fail("home must render reason prompt");
  }
  if (rel.includes("TheoryChangeFeed") && !src.includes("markReturnExpectationPromptEligible")) {
    fail("TheoryChangeFeed must arm expectation prompt");
  }
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:return-trigger-attribution")) {
  fail("package.json missing validate:return-trigger-attribution");
}

const storage = new Map();
globalThis.window = globalThis;
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
  clearReturnTriggerAttributionForEval,
  observeReturnVisitForAttribution,
  shouldShowReturnTriggerReasonPrompt,
  saveReturnTriggerReason,
  markReturnExpectationPromptEligible,
  shouldShowReturnExpectationPrompt,
  saveReturnExpectationMet,
} = await import("../lib/retention/return-trigger-attribution.ts");
const { clearReturnTriggerAttributionEventsForEval } = await import(
  "../lib/metrics/return-trigger-attribution-events.ts"
);
const { buildReturnTriggerAttributionReport } = await import(
  "../lib/internal/return-trigger-attribution-report.ts"
);

clearReturnTriggerAttributionForEval();
clearReturnTriggerAttributionEventsForEval();

const past = new Date(Date.now() - 30 * 60 * 60 * 1000).toISOString();
storage.set("voicememory_return_attribution_last_open", past);
observeReturnVisitForAttribution();
assert.ok(shouldShowReturnTriggerReasonPrompt(), "24h return should arm reason prompt");

const record = saveReturnTriggerReason("archive_view_changed");
assert.equal(record.reason, "archive_view_changed");

markReturnExpectationPromptEligible();
const ctx = shouldShowReturnExpectationPrompt();
assert.ok(ctx, "discover open should show expectation prompt");
saveReturnExpectationMet("yes", ctx);
assert.equal(shouldShowReturnExpectationPrompt(), null);

const report = buildReturnTriggerAttributionReport();
assert.ok(report.criticalQuestion.includes("come back"));
assert.equal(report.totalReasonResponses, 1);
assert.equal(report.totalExpectationResponses, 1);
assert.equal(report.mostCommonReason, "archive_view_changed");

if (failures.length) {
  console.error("validate-return-trigger-attribution failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-return-trigger-attribution ok", {
  reason: report.mostCommonReason,
  answer: report.criticalAnswer.slice(0, 60),
});
