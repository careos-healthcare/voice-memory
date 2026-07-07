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

const FORBIDDEN =
  /\b(diagnos|disorder|patholog|clinical|therapy|counsel|treatment|cure|mental health|guaranteed insight|you are always)\b/i;

const storage = new Map();
process.env.NODE_ENV = "production";
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

const required = [
  "types/value-moment-paywall.ts",
  "lib/billing/value-moment-paywall.ts",
  "lib/billing/value-moment-paywall-copy.ts",
  "lib/billing/value-moment-paywall-metrics.ts",
  "components/billing/ValueMomentPaywall.tsx",
  "components/billing/ValueMomentContinuityGate.tsx",
  "components/internal/ValueMomentPaywallPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

function makeEntries(count) {
  return Array.from({ length: count }, (_, i) => ({
    id: `e${i + 1}`,
    createdAt: new Date(`2026-01-${String(i + 1).padStart(2, "0")}T12:00:00.000Z`).toISOString(),
    transcript: `I keep circling the same worry about work and money entry ${i + 1}.`,
    reflectionPending: false,
  }));
}

const {
  readValueMomentState,
  markFirstBlindSpotSeen,
  markFirstDiscoverSeen,
  markPostBlindSpotPaywallSeen,
  markPostDiscoverPaywallSeen,
  recordBlindSpotsPageVisit,
  recordDiscoverPageVisit,
  shouldShowValueMomentPaywall,
  resetValueMomentPaywallForTests,
  shouldBypassValueMomentPaywall,
  VALUE_MOMENT_REFLECTION_TARGET,
} = await import("../lib/billing/value-moment-paywall.ts");

const {
  VALUE_MOMENT_PAYWALL_COPY,
  VALUE_MOMENT_PRICING_COPY,
} = await import("../lib/billing/value-moment-paywall-copy.ts");

const {
  buildValueMomentPaywallMetricsReport,
  trackValueMomentPaywallShown,
  trackValueMomentPaywallCtaClicked,
  trackValueMomentPaywallDismissed,
  clearValueMomentPaywallMetricsForEval,
} = await import("../lib/billing/value-moment-paywall-metrics.ts");

const { setPreviewTier } = await import("../lib/entitlement/entitlements.ts");

resetValueMomentPaywallForTests();
clearValueMomentPaywallMetricsForEval();

const entries5 = makeEntries(5);

// First blind spot visit — free, no post paywall
recordBlindSpotsPageVisit();
markFirstBlindSpotSeen();
assert.equal(
  shouldShowValueMomentPaywall("blind_spot", entries5),
  false,
  "first blind spot visit must not paywall",
);

// Second visit with 5+ reflections — paywall after value
recordBlindSpotsPageVisit();
assert.equal(
  shouldShowValueMomentPaywall("blind_spot", entries5),
  true,
  "revisit blind spot with 5+ must show post-value paywall",
);

// Under 5 reflections — no post-blind-spot paywall
resetValueMomentPaywallForTests();
recordBlindSpotsPageVisit();
markFirstBlindSpotSeen();
recordBlindSpotsPageVisit();
assert.equal(
  shouldShowValueMomentPaywall("blind_spot", makeEntries(4)),
  false,
  "<5 reflections must not show post-blind-spot paywall",
);

// First discover — free
resetValueMomentPaywallForTests();
recordDiscoverPageVisit();
markFirstDiscoverSeen();
assert.equal(
  shouldShowValueMomentPaywall("discover", entries5),
  false,
  "first discover visit must not paywall",
);

recordDiscoverPageVisit();
assert.equal(
  shouldShowValueMomentPaywall("discover", entries5),
  true,
  "second discover visit must show post-discover paywall",
);

// Pro bypass
resetValueMomentPaywallForTests();
setPreviewTier("pro");
assert.equal(shouldBypassValueMomentPaywall(), true);
recordBlindSpotsPageVisit();
recordBlindSpotsPageVisit();
markFirstBlindSpotSeen();
assert.equal(shouldShowValueMomentPaywall("blind_spot", entries5), false);

// Founder preview bypass
resetValueMomentPaywallForTests();
setPreviewTier("free");
storage.set("voicememory_founder_pro_preview", "1");
assert.equal(shouldBypassValueMomentPaywall(), true);

resetValueMomentPaywallForTests();
setPreviewTier("free");

// Copy
assert.ok(VALUE_MOMENT_PAYWALL_COPY.continuityLine.includes("ChatGPT"));
assert.ok(VALUE_MOMENT_PAYWALL_COPY.headline.includes("Keep the archive evolving"));
assert.ok(VALUE_MOMENT_PRICING_COPY.freeFeatures.some((f) => f.includes("First proof")));
assert.ok(VALUE_MOMENT_PRICING_COPY.proFeatures.some((f) => f.includes("Full pattern timeline")));
assert.equal(VALUE_MOMENT_PRICING_COPY.priceLabel, "£9.99/month");
assert.equal(VALUE_MOMENT_REFLECTION_TARGET, 5);

for (const rel of [
  "lib/billing/value-moment-paywall-copy.ts",
  "components/billing/ValueMomentPaywall.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (FORBIDDEN.test(src)) fail(`${rel} contains forbidden language`);
}

// Metrics
resetValueMomentPaywallForTests();
clearValueMomentPaywallMetricsForEval();
trackValueMomentPaywallShown("blind_spot");
trackValueMomentPaywallCtaClicked("blind_spot");
trackValueMomentPaywallDismissed("discover");

const metrics = buildValueMomentPaywallMetricsReport();
assert.ok(metrics.shownCount >= 1);
assert.equal(metrics.ctaClickRate, 100);
assert.equal(metrics.dismissRate, 100);
assert.ok(metrics.shownAfterBlindSpotCount >= 1);
assert.ok(metrics.shownAfterDiscoverCount >= 0);

// Route wiring
for (const rel of [
  "components/blind-spots/BlindSpotReview.tsx",
  "components/discover/TheoryChangeFeed.tsx",
  "app/internal/retention-discovery/page.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("ValueMomentPaywall")) fail(`${rel} must wire ValueMomentPaywall`);
}

const retentionSrc = fs.readFileSync(
  path.join(ROOT, "app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!retentionSrc.includes("ValueMomentPaywallPanel")) {
  fail("retention-discovery must wire ValueMomentPaywallPanel");
}

const paywallSrc = fs.readFileSync(
  path.join(ROOT, "components/billing/ValueMomentPaywall.tsx"),
  "utf8",
);
if (!paywallSrc.includes("VALUE_MOMENT_PAYWALL_COPY")) {
  fail("ValueMomentPaywall must render VALUE_MOMENT_PAYWALL_COPY");
}
const copySrc = fs.readFileSync(
  path.join(ROOT, "lib/billing/value-moment-paywall-copy.ts"),
  "utf8",
);
if (!copySrc.includes("Keep the full timeline")) {
  fail("paywall copy must include primary CTA");
}
if (!copySrc.includes("Not now")) fail("paywall copy must include dismiss");

const progressSrc = fs.readFileSync(
  path.join(ROOT, "lib/billing/value-moment-paywall.ts"),
  "utf8",
);
if (/new PatternEngine|buildBlindSpotReview\(/i.test(progressSrc)) {
  fail("value-moment-paywall must not add analysis engines");
}

if (failures.length > 0) {
  console.error("validate-value-moment-paywall failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-value-moment-paywall ok");
