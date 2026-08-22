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
  "packages/shared/types/founder-test.ts",
  "packages/shared/lib/founder-test/founder-test-storage.ts",
  "packages/shared/lib/founder-test/founder-test-checklist.ts",
  "packages/shared/lib/founder-test/founder-test-thresholds.ts",
  "packages/shared/lib/founder-test/founder-test-report.ts",
  "packages/shared/lib/founder-test/founder-evolving-validation.ts",
  "apps/web/components/internal/FounderEvolvingValidationPanel.tsx",
  "apps/web/components/internal/FounderTestPanel.tsx",
  "apps/web/components/internal/FounderTestParticipantCard.tsx",
  "apps/web/components/internal/FounderTestChecklist.tsx",
  "apps/web/components/internal/FounderTestReportPanel.tsx",
  "apps/web/app/internal/founder-test/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const {
  FOUNDER_TEST_CHECKLIST_ITEM_IDS,
  FOUNDER_TEST_CHECKLIST_LABELS,
  FOUNDER_TEST_INTERVIEW_QUESTIONS,
  FOUNDER_EVOLVING_INTERVIEW_QUESTIONS,
  FOUNDER_TEST_CORE_QUESTION,
  buildDefaultFounderTestChecklist,
} = await import("../packages/shared/lib/founder-test/founder-test-checklist.ts");
const {
  buildFounderEvolvingValidationReport,
  classifyDiscoverExpectationVerbatim,
} = await import("../packages/shared/lib/founder-test/founder-evolving-validation.ts");
const {
  createFounderTestParticipant,
  updateFounderTestSession,
  readFounderTestSessions,
  readFounderTestRecords,
  markChecklistItem,
  clearFounderTestSessionsForEval,
} = await import("../packages/shared/lib/founder-test/founder-test-storage.ts");
const { buildFounderTestReport } = await import("../packages/shared/lib/founder-test/founder-test-report.ts");
const {
  classifyFounderTestStudySignal,
  FOUNDER_TEST_STRONG_THRESHOLDS,
  FOUNDER_TEST_WEAK_THRESHOLDS,
} = await import("../packages/shared/lib/founder-test/founder-test-thresholds.ts");

clearFounderTestSessionsForEval();

assert.equal(FOUNDER_TEST_CHECKLIST_ITEM_IDS.length, 10);
for (const id of FOUNDER_TEST_CHECKLIST_ITEM_IDS) {
  assert.ok(FOUNDER_TEST_CHECKLIST_LABELS[id], `missing label for ${id}`);
}
assert.equal(buildDefaultFounderTestChecklist().length, 10);

assert.ok(
  FOUNDER_TEST_INTERVIEW_QUESTIONS.some((q) => /ChatGPT/i.test(q)),
  "interview must include ChatGPT differentiation",
);
assert.ok(FOUNDER_TEST_CORE_QUESTION.includes("ChatGPT"));
assert.equal(FOUNDER_EVOLVING_INTERVIEW_QUESTIONS.length, 4);
assert.equal(classifyDiscoverExpectationVerbatim("whether confidence changed"), "good");
assert.equal(classifyDiscoverExpectationVerbatim("nothing really"), "weak");
assert.equal(
  classifyDiscoverExpectationVerbatim("I wanted another insight"),
  "weak",
);
assert.equal(
  classifyDiscoverExpectationVerbatim("whether ArchiveMe had changed its mind"),
  "good",
);

const evolvingSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/founder-test/founder-evolving-validation.ts"),
  "utf8",
);
for (const phrase of [
  "Returned to Check Archive View Rate",
  "Theory Accuracy History",
  "building a case about me",
  "10–20",
]) {
  if (!evolvingSrc.includes(phrase)) fail(`founder-evolving-validation missing: ${phrase}`);
}

const p1 = createFounderTestParticipant("Tester A");
const p2 = createFounderTestParticipant("Tester B");
assert.equal(readFounderTestSessions().length, 2);

updateFounderTestSession(p1.participant.id, {
  reflectionCount: 5,
  reachedFiveReflections: true,
  openedBlindSpots: true,
  openedDiscover: true,
  firstBlindSpotReaction: "surprising",
  returnedWithin7Days: true,
  understoodChatGptDifference: true,
  wouldPay: true,
  mainQuote: "I finally saw the loop",
  framingAccuracyPreference: "working_theory",
  discoverExpectationVerbatim: "whether the archive changed its mind",
  discoverExpectationQuality: "good",
  theoryCuriosityAnswer: "yes",
  returnedToCheckArchiveView: true,
});

updateFounderTestSession(p2.participant.id, {
  reflectionCount: 2,
  reachedFiveReflections: false,
  openedBlindSpots: false,
  firstBlindSpotReaction: "obvious",
  returnedWithin7Days: false,
  understoodChatGptDifference: false,
  wouldPay: false,
  biggestConfusion: "why not just use chatgpt",
});

markChecklistItem(p1.participant.id, "five_reflections", true);
const updated = readFounderTestSessions().find((s) => s.participantId === p1.participant.id);
assert.ok(updated?.reachedFiveReflections);

const report = buildFounderTestReport();
assert.equal(report.totalParticipants, 2);
assert.equal(report.reachedFiveRate, 50);
assert.equal(report.blindSpotOpenRate, 50);
assert.equal(report.discoverOpenRate, 50);
assert.equal(report.surprisingOrAccurateRate, 50);
assert.equal(report.sevenDayReturnRate, 50);
assert.equal(report.chatGptDifferenceUnderstoodRate, 50);
assert.equal(report.wouldPayRate, 50);
assert.ok(report.redFlags.length >= 2);
assert.ok(report.strongestQuotes.includes("I finally saw the loop"));
assert.ok(report.evolvingValidation);
assert.equal(report.evolvingValidation.workingTheoryPreferredRate, 100);
assert.equal(report.evolvingValidation.discoverExpectationGoodRate, 100);
assert.ok(buildFounderEvolvingValidationReport(readFounderTestRecords()).device);

function strongParticipant(id, label) {
  const now = new Date().toISOString();
  return {
    participant: { id, label, startedAt: now, targetReflectionCount: 5 },
    session: {
      participantId: id,
      reflectionCount: 6,
      reachedFiveReflections: true,
      openedBlindSpots: true,
      openedDiscover: true,
      firstBlindSpotReaction: "surprising",
      returnedWithin7Days: true,
      understoodChatGptDifference: true,
      wouldPay: true,
      mainQuote: `Quote from ${label}`,
      createdAt: now,
      updatedAt: now,
    },
    checklist: buildDefaultFounderTestChecklist(),
  };
}

const strongReport = buildFounderTestReport([
  strongParticipant("s1", "S1"),
  strongParticipant("s2", "S2"),
  strongParticipant("s3", "S3"),
  strongParticipant("s4", "S4"),
]);
assert.equal(classifyFounderTestStudySignal(strongReport), "strong_signal");

const weakReport = buildFounderTestReport([
  {
    participant: { id: "w1", label: "W1", startedAt: new Date().toISOString(), targetReflectionCount: 5 },
    session: {
      participantId: "w1",
      reflectionCount: 1,
      reachedFiveReflections: false,
      openedBlindSpots: false,
      openedDiscover: false,
      returnedWithin7Days: false,
      understoodChatGptDifference: false,
      wouldPay: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    checklist: buildDefaultFounderTestChecklist(),
  },
  {
    participant: { id: "w2", label: "W2", startedAt: new Date().toISOString(), targetReflectionCount: 5 },
    session: {
      participantId: "w2",
      reflectionCount: 2,
      reachedFiveReflections: false,
      openedBlindSpots: false,
      openedDiscover: false,
      returnedWithin7Days: false,
      understoodChatGptDifference: false,
      wouldPay: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    checklist: buildDefaultFounderTestChecklist(),
  },
  {
    participant: { id: "w3", label: "W3", startedAt: new Date().toISOString(), targetReflectionCount: 5 },
    session: {
      participantId: "w3",
      reflectionCount: 2,
      reachedFiveReflections: false,
      openedBlindSpots: false,
      openedDiscover: false,
      returnedWithin7Days: false,
      understoodChatGptDifference: false,
      wouldPay: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    checklist: buildDefaultFounderTestChecklist(),
  },
]);
assert.equal(classifyFounderTestStudySignal(weakReport), "weak_signal");

assert.equal(FOUNDER_TEST_STRONG_THRESHOLDS.reachedFiveRate, 60);
assert.equal(FOUNDER_TEST_WEAK_THRESHOLDS.reachedFiveRate, 40);

const pagePath = path.join(ROOT, "apps/web/app/internal/founder-test/page.tsx");
if (!fs.existsSync(pagePath)) fail("internal route missing");
const pageSrc = fs.readFileSync(pagePath, "utf8");
if (!pageSrc.includes("FounderTestPanel")) fail("page must render FounderTestPanel");

const retentionSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!retentionSrc.includes("Founder user-study checklist")) {
  fail("retention-discovery must link founder test");
}

const forbiddenEngine = [
  "packages/shared/lib/patterns/pattern-engine",
  "packages/shared/lib/blind-spots/blind-spot-review.ts",
  "packages/shared/lib/blind-spots/blind-spot-ranking.ts",
  "packages/shared/lib/insights/insight-ingredient-optimizer.ts",
];
for (const rel of [
  "packages/shared/lib/founder-test/founder-test-storage.ts",
  "packages/shared/lib/founder-test/founder-test-report.ts",
  "apps/web/components/internal/FounderTestPanel.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const eng of forbiddenEngine) {
    if (src.includes(eng.replace(".ts", ""))) fail(`${rel} must not import ${eng}`);
  }
}

const publicPaths = ["apps/web/app/page.tsx", "apps/web/components/SiteHeader.tsx", "apps/web/app/layout.tsx"];
for (const rel of publicPaths) {
  const full = path.join(ROOT, rel);
  if (fs.existsSync(full)) {
    const src = fs.readFileSync(full, "utf8");
    if (src.includes("/internal/founder-test")) {
      fail(`${rel} must not link /internal/founder-test in public nav`);
    }
  }
}

const FORBIDDEN =
  /\b(diagnos|disorder|patholog|clinical|therapy|counsel|coach|treatment|you are always|guaranteed)\b/i;
const checklistSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/founder-test/founder-test-checklist.ts"),
  "utf8",
);
if (FORBIDDEN.test(checklistSrc)) fail("checklist copy must avoid forbidden framing");

if (failures.length > 0) {
  console.error("validate-founder-test failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-founder-test ok");
