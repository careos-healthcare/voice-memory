#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

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

function mustInclude(fileRel, tokens) {
  const src = fs.readFileSync(path.join(ROOT, fileRel), "utf8");
  for (const token of tokens) {
    if (!src.includes(token)) failures.push(`${fileRel} missing: ${token}`);
  }
}

const requiredFiles = [
  "lib/product/product-clarity-copy.ts",
  "lib/product/pattern-activation.ts",
  "lib/product/returning-home.ts",
  "lib/product/archive-product-copy.ts",
  "components/archive/ArchiveProductWayfinding.tsx",
  "lib/product/activation-metrics.ts",
  "components/product/PatternActivationProgress.tsx",
  "components/product/HomepageChatGptComparison.tsx",
  "components/product/ProductDemoStory.tsx",
  "components/product/ReturningDiscoverRedirect.tsx",
  "components/internal/ActivationMetricsPanel.tsx",
  "lib/product/activation-theory-preview.ts",
  "components/product/ActivationTheoryPreview.tsx",
  "components/product/FirstBlindSpotSimulator.tsx",
  "components/product/ArchiveValueBanner.tsx",
  "components/product/ReflectionValueLadder.tsx",
  "lib/product/archive-value-progress.ts",
  "lib/billing/value-moment-paywall-copy.ts",
  "components/billing/ValueMomentPaywall.tsx",
  "lib/archive/archive-worth.ts",
  "components/archive/ArchiveWorthStatement.tsx",
  "lib/product/archive-product-model.ts",
  "components/archive/ArchiveCommandCenter.tsx",
  "lib/product/product-simplification-copy.ts",
];

for (const rel of requiredFiles) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

mustInclude("lib/product/product-clarity-copy.ts", [
  "LANDING_3_DAY_CHALLENGE",
  "See what keeps coming back.",
  "ChatGPT helps you think today. ArchiveMe shows what keeps repeating across your life.",
  "Each reflection gives ArchiveMe more evidence",
  "criticism means you're failing",
  "reflections toward your first belief",
  "working view from repeated evidence",
  "EVOLVING_VIEW_INTRO",
]);

mustInclude("lib/theories/personal-theory-copy.ts", ["See what changed"]);
mustInclude("lib/product/archive-product-copy.ts", [
  "Check the state of your archive",
  "See archive changes",
]);

mustInclude("app/page.tsx", [
  "ReturningDiscoverRedirect",
  "HomepageChatGptComparison",
  "ProductDemoStory",
  "PatternActivationProgress",
  "ThreeDayProofChallengeLanding",
  "HomeArchiveBeliefIntro",
  "EvidenceArchivePreview",
  "ArchiveMaturityMeter",
  "WhatThisArchiveCanAnswer",
]);

mustInclude("app/archive-belief/page.tsx", ["EvidenceArchiveHome"]);
mustInclude("components/archive/EvidenceArchiveHome.tsx", [
  "ArchiveCommandCenter",
  "PAGE_TITLE_ARCHIVE",
]);
mustInclude("app/memory/page.tsx", [
  "ActivationTheoryPreview",
  "FirstBlindSpotSimulator",
  "PatternActivationProgress",
  "ArchiveValueBanner",
  "ReflectionValueLadder",
  "EvidenceArchivePreview",
  "SessionMovementSummary",
  "ArchiveAssetCard",
  "ArchiveProductWayfinding",
  "MEMORY_PAGE_UTILITY_TITLE",
]);

mustInclude("app/discover/page.tsx", [
  "DISCOVER_PAGE.heading",
  "TheoryChangeFeed",
  "ArchiveProductWayfinding",
]);
mustInclude("lib/billing/value-moment-paywall-copy.ts", [
  "ChatGPT can help with today's question",
  "First 5 reflections",
  "First working belief",
  "Keep the evolving archive alive",
  "Full evidence timeline",
  "VALUE_MOMENT_PRO_PRICE_LABEL",
]);
mustInclude("lib/theories/personal-theory-copy.ts", [
  "What your archive currently believes",
]);

const copySrc = fs.readFileSync(
  path.join(ROOT, "lib/product/product-clarity-copy.ts"),
  "utf8",
);
if (/\bcoaching\b/i.test(copySrc)) failures.push("product-clarity-copy must not say coaching");
if (/\btherapy\b/i.test(copySrc) && !/not therapy/i.test(copySrc)) {
  failures.push("product-clarity-copy must not promote therapy");
}
if (/diagnos/i.test(copySrc) && !/not a diagnos/i.test(copySrc)) {
  failures.push("product-clarity-copy must not diagnose");
}

const {
  buildPatternActivationProgress,
  PATTERN_REVIEW_REFLECTION_TARGET,
} = await import("../lib/product/pattern-activation.ts");
const progress = buildPatternActivationProgress(2);
assert.equal(progress?.line, "2/5 reflections toward your first belief.");
assert.equal(PATTERN_REVIEW_REFLECTION_TARGET, 5);

const { buildActivationMetricsReport, ACTIVATION_METRIC_EVENTS, observeActivationReflectionCount } =
  await import("../lib/product/activation-metrics.ts");
const { trackLocalEvent } = await import("../lib/local-analytics.ts");

observeActivationReflectionCount(5);
const report = buildActivationMetricsReport();
assert.ok(report.fiveReflectionsRate !== null);
assert.ok(report.lines.length === 3);
assert.ok(ACTIVATION_METRIC_EVENTS.fiveReflectionsReached);

const returningSrc = fs.readFileSync(
  path.join(ROOT, "lib/product/returning-home.ts"),
  "utf8",
);
assert.ok(returningSrc.includes("shouldAutoRedirectToArchiveBelief"));
assert.ok(returningSrc.includes("/archive-belief"));

mustInclude("components/SiteHeader.tsx", [
  "SIMPLICITY_PRIMARY_NAV",
  "/archive-belief",
]);
mustInclude("lib/product/simplicity-mode.ts", [
  'label: "Record"',
  'label: "Archive"',
  'label: "Archive Activity"',
]);

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:product-clarity")) {
  failures.push("package.json missing validate:product-clarity");
}

if (failures.length > 0) {
  console.error("validate-product-clarity failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-product-clarity ok");
