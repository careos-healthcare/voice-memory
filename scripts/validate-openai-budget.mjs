#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/** Force in-memory spend counters for deterministic CI (no Neon). */
delete process.env.DATABASE_URL;

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

for (const rel of [
  "lib/server/openai-cost-estimator.ts",
  "lib/server/openai-budget-core.ts",
  "lib/server/openai-budget-guard.ts",
  "lib/server/openai-spend-store.ts",
  "lib/server/api-limits.ts",
  "lib/recording/openai-api-response.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const guard = fs.readFileSync(path.join(ROOT, "lib/server/api-guard.ts"), "utf8");
if (!guard.includes("guardOpenAiBudget")) {
  fail("api-guard must enforce OpenAI budget");
}

const db = fs.readFileSync(path.join(ROOT, "lib/server/db.ts"), "utf8");
if (!db.includes("openai_daily_spend")) {
  fail("db schema must include openai_daily_spend");
}

const weekly = fs.readFileSync(path.join(ROOT, "app/api/weekly-reflection/route.ts"), "utf8");
if (!weekly.includes("guardOpenAiRoute")) {
  fail("weekly-reflection must use guardOpenAiRoute");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:openai-budget"]) {
  fail("package.json missing validate:openai-budget");
}

const {
  estimateTranscribeCost,
  estimateAnalyzeCost,
} = await import("../lib/server/openai-cost-estimator.ts");
const { getOpenAiBudgetLimits } = await import("../lib/server/openai-budget-core.ts");
const { reserveOpenAiSpend, peekOpenAiSpend } = await import("../lib/server/openai-spend-store.ts");

assert.ok(estimateTranscribeCost({ durationSeconds: 45 }) > 0);
assert.ok(estimateAnalyzeCost(1000) > 0);
assert.ok(getOpenAiBudgetLimits().globalMicro > 0);

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

const subject = `validate-openai-${Date.now()}`;
const ok = await reserveOpenAiSpend(subject, 100, 500);
assert.equal(ok.ok, true);
assert.equal(await peekOpenAiSpend(subject), 100);

const { runOpenAiBudgetTests } = await import("../lib/reliability/openai-budget-tests.ts");
const { failures: testFailures } = await runOpenAiBudgetTests();
if (testFailures.length) {
  fail(`openai-budget-tests:\n${testFailures.join("\n")}`);
}

if (failures.length) {
  console.error("validate:openai-budget failed:\n" + failures.map((f) => `  - ${f}`).join("\n"));
  process.exit(1);
}

console.log("validate:openai-budget OK");
