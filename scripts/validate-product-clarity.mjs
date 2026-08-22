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
  "packages/shared/lib/product/product-clarity-copy.ts",
  "packages/shared/lib/product/pattern-activation.ts",
  "packages/shared/lib/product/returning-home.ts",
  "packages/shared/lib/product/archive-product-copy.ts",
  "apps/web/components/archive/ArchiveProductWayfinding.tsx",
  "packages/shared/lib/product/activation-metrics.ts",
  "apps/web/components/product/PatternActivationProgress.tsx",
  "apps/web/components/product/HomepageChatGptComparison.tsx",
  "apps/web/components/product/ProductDemoStory.tsx",
  "apps/web/components/product/ReturningDiscoverRedirect.tsx",
  "apps/web/components/internal/ActivationMetricsPanel.tsx",
  "packages/shared/lib/product/activation-theory-preview.ts",
  "apps/web/components/product/ActivationTheoryPreview.tsx",
  "apps/web/components/product/FirstBlindSpotSimulator.tsx",
  "apps/web/components/product/ArchiveValueBanner.tsx",
  "apps/web/components/product/ReflectionValueLadder.tsx",
  "packages/shared/lib/product/archive-value-progress.ts",
  "packages/shared/lib/billing/value-moment-paywall-copy.ts",
  "apps/web/components/billing/ValueMomentPaywall.tsx",
  "packages/shared/lib/archive/archive-worth.ts",
  "apps/web/components/archive/ArchiveWorthStatement.tsx",
  "packages/shared/lib/product/archive-product-model.ts",
  "apps/web/components/archive/ArchiveCommandCenter.tsx",
  "packages/shared/lib/product/product-simplification-copy.ts",
];

for (const rel of requiredFiles) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

mustInclude("packages/shared/lib/product/product-clarity-copy.ts", [
  "LANDING_3_DAY_CHALLENGE",
  "LANDING_3_DAY_CHALLENGE.hero",
  "LANDING_3_DAY_CHALLENGE.chatGptDifferentiation",
  "Each moment gives ArchiveMe more evidence",
  "criticism means you're failing",
  "reflections toward your first belief",
  "working view from repeated evidence",
  "EVOLVING_VIEW_INTRO",
]);

mustInclude("packages/shared/lib/theories/personal-theory-copy.ts", ["See what changed"]);
mustInclude("packages/shared/lib/product/archive-product-copy.ts", [
  "Check the state of your archive",
  "See archive changes",
]);

mustInclude("apps/web/app/page.tsx", [
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

mustInclude("apps/web/app/archive-belief/page.tsx", ["EvidenceArchiveHome"]);
mustInclude("apps/web/components/archive/EvidenceArchiveHome.tsx", [
  "ArchiveCommandCenter",
  "PAGE_TITLE_ARCHIVE",
]);
mustInclude("apps/web/app/memory/page.tsx", [
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

mustInclude("apps/web/app/discover/page.tsx", [
  "DISCOVER_PAGE.heading",
  "TheoryChangeFeed",
  "ArchiveProductWayfinding",
]);
mustInclude("packages/shared/lib/billing/value-moment-paywall-copy.ts", [
  "ChatGPT can answer a conversation",
  "First proof from your saves",
  "First working belief",
  "Pro keeps the full timeline as it grows",
  "Full pattern timeline",
  "VALUE_MOMENT_PRO_PRICE_LABEL",
]);
mustInclude("packages/shared/lib/theories/personal-theory-copy.ts", [
  "What your archive currently believes",
]);

const copySrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/product-clarity-copy.ts"),
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
} = await import("../packages/shared/lib/product/pattern-activation.ts");
const progress = buildPatternActivationProgress(2);
assert.equal(progress?.line, "2/5 reflections toward your first belief.");
assert.equal(PATTERN_REVIEW_REFLECTION_TARGET, 5);

const { buildActivationMetricsReport, ACTIVATION_METRIC_EVENTS, observeActivationReflectionCount } =
  await import("../packages/shared/lib/product/activation-metrics.ts");
const { trackLocalEvent } = await import("../packages/shared/lib/local-analytics.ts");

observeActivationReflectionCount(5);
const report = buildActivationMetricsReport();
assert.ok(report.fiveReflectionsRate !== null);
assert.ok(report.lines.length === 3);
assert.ok(ACTIVATION_METRIC_EVENTS.fiveReflectionsReached);

const returningSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/returning-home.ts"),
  "utf8",
);
assert.ok(returningSrc.includes("shouldAutoRedirectToArchiveBelief"));
assert.ok(returningSrc.includes("/archive-belief"));

mustInclude("apps/web/components/SiteHeader.tsx", [
  "SIMPLICITY_PRIMARY_NAV",
  "/archive-belief",
]);
mustInclude("packages/shared/lib/product/simplicity-mode.ts", [
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
