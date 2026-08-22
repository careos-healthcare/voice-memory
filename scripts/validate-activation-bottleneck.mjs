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
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      ...reflection,
    },
    durationSeconds: 40,
  };
}

function makeArchive(count) {
  const lines = [
    "I keep saying I will start Monday but I never do.",
    "I want to change but I keep doing the same thing at work.",
    "I keep avoiding the conversation with my manager.",
    "Maybe I will eventually tell them — I don't know.",
    "I keep circling the same worry about money and work.",
    "I should have spoken up but I keep waiting to quit.",
    "I think this will fall apart and I keep putting it off.",
  ];
  return Array.from({ length: count }, (_, i) =>
    entry(`e${i + 1}`, (i + 1) * 4, lines[i % lines.length]),
  );
}

const required = [
  "packages/shared/lib/product/activation-theory-preview.ts",
  "packages/shared/lib/product/first-blind-spot-simulator.ts",
  "packages/shared/lib/product/first-blind-spot-simulator-copy.ts",
  "packages/shared/lib/product/activation-bottleneck-metrics.ts",
  "apps/web/components/product/ActivationTheoryPreview.tsx",
  "apps/web/components/product/FirstBlindSpotSimulator.tsx",
  "apps/web/components/product/FirstBlindSpotExampleReviewModal.tsx",
  "apps/web/components/internal/ActivationBottleneckPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const {
  buildActivationTheoryPreview,
  passesTheoryPreviewCopyGate,
  FORBIDDEN_THEORY_PREVIEW,
  ACTIVATION_THEORY_PREVIEW_DISCLAIMER,
} = await import("../packages/shared/lib/product/activation-theory-preview.ts");
const {
  buildFirstBlindSpotSimulatorView,
  buildFirstBlindSpotExampleReview,
  shouldShowFirstBlindSpotSimulator,
} = await import("../packages/shared/lib/product/first-blind-spot-simulator.ts");
const { FIRST_BLIND_SPOT_SIMULATOR } = await import(
  "../packages/shared/lib/product/first-blind-spot-simulator-copy.ts"
);
const {
  buildActivationBottleneckMetricsReport,
  observeActivationBottleneckMilestones,
  trackActivationTheoryPreviewShown,
  trackActivationTheoryPreviewClicked,
  trackFirstBlindSpotSimulatorShown,
  trackFirstBlindSpotSimulatorExampleOpened,
  trackFirstBlindSpotSimulatorCtaClicked,
  clearActivationBottleneckForEval,
  ACTIVATION_BOTTLENECK_EVENTS,
} = await import("../packages/shared/lib/product/activation-bottleneck-metrics.ts");

assert.equal(buildActivationTheoryPreview(makeArchive(2)), null, "<3 returns null");

const at3 = buildActivationTheoryPreview(makeArchive(3));
assert.ok(at3, "3 reflections should return preview");
assert.equal(at3.remainingCount, 2);
assert.ok(at3.unlockCopy.includes("2 more reflection"));
assert.equal(at3.reflectionCount, 3);

const at4 = buildActivationTheoryPreview(makeArchive(4));
assert.ok(at4);
assert.equal(at4.remainingCount, 1);
assert.ok(at4.unlockCopy.includes("1 more reflection"));

assert.equal(buildActivationTheoryPreview(makeArchive(5)), null, "5+ returns null");
assert.equal(buildActivationTheoryPreview(makeArchive(6)), null);

assert.ok(at3.disclaimer.includes(ACTIVATION_THEORY_PREVIEW_DISCLAIMER));
assert.ok(/\bmay\b/i.test(at3.possibleTheory) || /\bmight\b/i.test(at3.possibleTheory));
assert.ok(passesTheoryPreviewCopyGate(at3));
assert.ok(!FORBIDDEN_THEORY_PREVIEW.test(at3.possibleTheory));
assert.ok(at3.nextReflectionCopy.includes("next reflection"));

assert.equal(shouldShowFirstBlindSpotSimulator(2), false);
assert.equal(shouldShowFirstBlindSpotSimulator(3), true);
assert.equal(shouldShowFirstBlindSpotSimulator(4), true);
assert.equal(shouldShowFirstBlindSpotSimulator(5), false);

const sim3 = buildFirstBlindSpotSimulatorView(3);
assert.ok(sim3);
assert.equal(sim3.progressLine, FIRST_BLIND_SPOT_SIMULATOR.progressAt3);
assert.equal(sim3.headline, FIRST_BLIND_SPOT_SIMULATOR.headline);
assert.equal(sim3.categories.length, 3);

const sim4 = buildFirstBlindSpotSimulatorView(4);
assert.ok(sim4);
assert.equal(sim4.progressLine, FIRST_BLIND_SPOT_SIMULATOR.progressAt4);
assert.equal(buildFirstBlindSpotSimulatorView(5), null);

const example = buildFirstBlindSpotExampleReview();
assert.ok(example.patternHeadline.length > 10);
assert.ok(example.evidenceQuotes.length >= 2);
assert.ok(example.whatChanged.length >= 1);
assert.ok(example.disclaimer.toLowerCase().includes("not"));

clearActivationBottleneckForEval();
observeActivationBottleneckMilestones(4);
observeActivationBottleneckMilestones(5);
trackActivationTheoryPreviewShown(3);
trackActivationTheoryPreviewClicked(3);
trackFirstBlindSpotSimulatorShown(3);
trackFirstBlindSpotSimulatorExampleOpened(3);
trackFirstBlindSpotSimulatorCtaClicked(3);

const report = buildActivationBottleneckMetricsReport();
assert.ok(report.totalReached4 >= 1);
assert.ok(report.totalReached5 >= 1);
assert.equal(report.reflection4To5ConversionRate, 100);
assert.ok(report.previewShownCount >= 1);
assert.ok(report.previewClickCount >= 1);
assert.ok(report.simulatorShownCount >= 1);
assert.ok(report.simulatorExampleOpenedCount >= 1);
assert.ok(report.simulatorCtaClickedCount >= 1);
assert.equal(report.conversionWithSimulatorRate, 100);

const memorySrc = fs.readFileSync(path.join(ROOT, "apps/web/app/memory/page.tsx"), "utf8");
const entrySrc = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
const recorderSrc = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
const retentionSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/retention-discovery/page.tsx"),
  "utf8",
);

if (!memorySrc.includes("ActivationTheoryPreview")) fail("memory page must wire preview");
if (!memorySrc.includes("FirstBlindSpotSimulator")) fail("memory page must wire simulator");
if (!entrySrc.includes("ActivationTheoryPreview")) fail("entry page must wire preview");
if (!entrySrc.includes("FirstBlindSpotSimulator")) fail("entry page must wire simulator");
if (!recorderSrc.includes("ActivationTheoryPreview")) fail("Recorder must wire preview");
if (!recorderSrc.includes("FirstBlindSpotSimulator")) fail("Recorder must wire simulator");
if (!retentionSrc.includes("ActivationBottleneckPanel")) {
  fail("retention-discovery must wire bottleneck panel");
}

const previewSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/activation-theory-preview.ts"),
  "utf8",
);
if (/\bcoaching\b/i.test(previewSrc) && !/not coaching/i.test(previewSrc)) {
  fail("activation-theory-preview must not use coaching framing");
}
if (/you are always/i.test(previewSrc)) fail("forbidden certainty in preview module");

assert.ok(
  Object.values(ACTIVATION_BOTTLENECK_EVENTS).includes("activation_theory_preview_shown"),
);
assert.ok(Object.values(ACTIVATION_BOTTLENECK_EVENTS).includes("simulator_shown"));
assert.ok(Object.values(ACTIVATION_BOTTLENECK_EVENTS).includes("simulator_example_opened"));
assert.ok(Object.values(ACTIVATION_BOTTLENECK_EVENTS).includes("simulator_cta_clicked"));

const simCopySrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/first-blind-spot-simulator-copy.ts"),
  "utf8",
);
if (/you are always/i.test(simCopySrc)) fail("simulator copy must avoid certainty");
if (!simCopySrc.includes("needs more evidence")) fail("simulator must hedge confidence");

if (failures.length > 0) {
  console.error("validate-activation-bottleneck failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-activation-bottleneck ok");
