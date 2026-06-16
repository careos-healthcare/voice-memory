#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "types/organic-referral.ts",
  "lib/retention/organic-referral-copy.ts",
  "lib/retention/organic-referral.ts",
  "lib/metrics/organic-referral-events.ts",
  "lib/internal/organic-referral-report.ts",
  "components/retention/OrganicReferralPrompt.tsx",
  "components/internal/OrganicReferralPanel.tsx",
  "app/internal/organic-referral/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "lib/retention/organic-referral-copy.ts"), "utf8");
for (const phrase of [
  "Have you told anyone about ArchiveMe?",
  "Thought about it",
  "What did you tell them?",
  "What would make this worth recommending?",
  "Blind spots",
  "Not sure yet",
  "ORGANIC_REFERRAL_STRONG_YES_PERCENT = 20",
  "ORGANIC_REFERRAL_WEAK_YES_PERCENT = 10",
]) {
  if (!copy.includes(phrase)) fail(`missing copy phrase: ${phrase}`);
}

const core = fs.readFileSync(path.join(ROOT, "lib/retention/organic-referral.ts"), "utf8");
if (!core.includes("ORGANIC_REFERRAL_MIN_REFLECTIONS = 5")) fail("min reflections");
if (!core.includes("ORGANIC_REFERRAL_COOLDOWN_MS = 14")) fail("cooldown");

const events = fs.readFileSync(
  path.join(ROOT, "lib/metrics/organic-referral-events.ts"),
  "utf8",
);
for (const name of ["organic_referral_status", "organic_referral_reason", "referral_blocker"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const prompt = fs.readFileSync(
  path.join(ROOT, "components/retention/OrganicReferralPrompt.tsx"),
  "utf8",
);
if (!prompt.includes("saveOrganicReferralStatus")) fail("prompt must save status");
if (!prompt.includes('data-testid="organic-referral-prompt"')) fail("status test id");

const report = fs.readFileSync(
  path.join(ROOT, "lib/internal/organic-referral-report.ts"),
  "utf8",
);
if (!report.includes("Would users naturally tell someone?")) fail("critical question");

if (!fs.readFileSync(path.join(ROOT, "app/memory/page.tsx"), "utf8").includes("OrganicReferralPrompt")) {
  fail("memory page must wire OrganicReferralPrompt");
}

const retentionPage = fs.readFileSync(
  path.join(ROOT, "app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!retentionPage.includes("OrganicReferralPanel")) fail("retention-discovery must wire panel");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:organic-referral")) fail("package.json missing script");

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-organic-referral" } };
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

const { trackLocalEvent } = await import("../lib/local-analytics.ts");
const { THEORY_EVENTS } = await import("../lib/theories/theory-events.ts");
const { ACTIVATION_METRIC_EVENTS } = await import("../lib/product/activation-metrics.ts");
const {
  clearOrganicReferralForEval,
  canShowOrganicReferralPrompt,
  saveOrganicReferralStatus,
  saveOrganicReferralReason,
  shouldShowOrganicReferralFollowUp,
  ORGANIC_REFERRAL_MIN_REFLECTIONS,
} = await import("../lib/retention/organic-referral.ts");
const { clearOrganicReferralEventsForEval } = await import(
  "../lib/metrics/organic-referral-events.ts"
);
const { buildOrganicReferralReport } = await import(
  "../lib/internal/organic-referral-report.ts"
);

clearOrganicReferralForEval();
clearOrganicReferralEventsForEval();

assert.equal(ORGANIC_REFERRAL_MIN_REFLECTIONS, 5);

const sparse = [
  {
    id: "a1",
    createdAt: "2026-01-01T12:00:00.000Z",
    transcript: "one",
    reflectionPending: false,
    reflection: { mood: "calm", hiddenConcern: "", recurringThemes: [] },
  },
];
assert.equal(canShowOrganicReferralPrompt(Date.now(), sparse), false);

trackLocalEvent(THEORY_EVENTS.discoverOpened);
trackLocalEvent(ACTIVATION_METRIC_EVENTS.strongInsightReaction);

const entries = [];
for (let i = 0; i < 6; i += 1) {
  entries.push({
    id: `e${i}`,
    createdAt: `2026-0${1 + Math.floor(i / 3)}-${String((i % 28) + 1).padStart(2, "0")}T12:00:00.000Z`,
    transcript: `reflection ${i} about work patterns`,
    reflectionPending: false,
    reflection: {
      mood: "reflective",
      hiddenConcern: "",
      recurringThemes: ["work"],
      emotionalIntensity: 3,
      positiveSignal: "",
      recommendation: "",
      concreteObservation: "note",
      repeatedSignal: "work",
    },
  });
}

assert.ok(canShowOrganicReferralPrompt(Date.now(), entries));

const record = saveOrganicReferralStatus("yes", entries);
assert.equal(record.status, "yes");

const ctx = shouldShowOrganicReferralFollowUp();
assert.ok(ctx);
assert.equal(ctx.kind, "referral_reason");
saveOrganicReferralReason("discover", ctx.attributionId);

const built = buildOrganicReferralReport();
assert.equal(built.totalResponses, 1);
assert.equal(built.referralRate, 100);
assert.equal(built.yesOrThoughtRate, 100);
assert.ok(built.referralReasons[0]?.id === "discover");

clearOrganicReferralForEval();
clearOrganicReferralEventsForEval();
trackLocalEvent(THEORY_EVENTS.discoverOpened);
trackLocalEvent(ACTIVATION_METRIC_EVENTS.strongInsightReaction);
saveOrganicReferralStatus("no", entries);
const blockerCtx = shouldShowOrganicReferralFollowUp();
assert.ok(blockerCtx);
assert.equal(blockerCtx.kind, "referral_blocker");
const { saveReferralBlocker } = await import("../lib/retention/organic-referral.ts");
saveReferralBlocker("not_sure_yet", blockerCtx.attributionId);
const built2 = buildOrganicReferralReport();
assert.equal(built2.referralBlockers[0]?.id, "not_sure_yet");

if (failures.length) {
  console.error("validate-organic-referral failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-organic-referral ok", {
  verdict: built.verdict,
  answer: built.criticalAnswer.slice(0, 64),
});
