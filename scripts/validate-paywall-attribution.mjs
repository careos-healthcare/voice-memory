#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "types/paywall-attribution.ts",
  "lib/billing/paywall-attribution-copy.ts",
  "lib/billing/paywall-attribution.ts",
  "lib/metrics/paywall-attribution-events.ts",
  "lib/internal/paywall-attribution-report.ts",
  "components/billing/PaywallRejectionPrompt.tsx",
  "components/billing/PaywallInterestPrompt.tsx",
  "components/billing/ConversionReasonPrompt.tsx",
  "components/internal/PaywallAttributionPanel.tsx",
  "app/internal/paywall-attribution/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "lib/billing/paywall-attribution-copy.ts"),
  "utf8",
);
for (const phrase of [
  "What stopped you upgrading?",
  "Too expensive",
  "What made Pro interesting?",
  "Belief changes",
  "What convinced you?",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const events = fs.readFileSync(
  path.join(ROOT, "lib/metrics/paywall-attribution-events.ts"),
  "utf8",
);
for (const name of ["paywall_rejection_reason", "paywall_interest_reason", "conversion_reason"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const paywall = fs.readFileSync(
  path.join(ROOT, "components/billing/ValueMomentPaywall.tsx"),
  "utf8",
);
if (!paywall.includes("PaywallRejectionPrompt")) fail("ValueMomentPaywall must show rejection prompt");
if (!paywall.includes("PaywallInterestPrompt")) fail("ValueMomentPaywall must show interest prompt");

const pricing = fs.readFileSync(
  path.join(ROOT, "app/pricing/PricingPageClient.tsx"),
  "utf8",
);
if (!pricing.includes("PaywallInterestPrompt")) fail("pricing must show interest prompt");
if (!pricing.includes("ConversionReasonPrompt")) fail("pricing must show conversion prompt");
if (!pricing.includes("armConversionReasonPrompt")) fail("pricing must arm conversion prompt");

const report = fs.readFileSync(
  path.join(ROOT, "lib/internal/paywall-attribution-report.ts"),
  "utf8",
);
if (!report.includes("What makes people pay?")) fail("report main question missing");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:paywall-attribution")) fail("package.json missing script");

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

const { clearPaywallAttributionForEval, savePaywallRejectionReason, savePaywallInterestReason, saveConversionReason, armConversionReasonPrompt, shouldShowConversionReasonPrompt } = await import("../lib/billing/paywall-attribution.ts");
const { clearPaywallAttributionEventsForEval } = await import("../lib/metrics/paywall-attribution-events.ts");
const { buildPaywallAttributionReport } = await import("../lib/internal/paywall-attribution-report.ts");
const { setPlanId } = await import("../lib/subscription.ts");

clearPaywallAttributionForEval();
clearPaywallAttributionEventsForEval();

savePaywallRejectionReason("too_expensive", { surface: "discover" });
const interest = savePaywallInterestReason("belief_changes", { source: "discover" });
assert.ok(interest.id);

setPlanId("pro");
armConversionReasonPrompt("checkout_success");
assert.ok(shouldShowConversionReasonPrompt());
saveConversionReason("belief_changes", { source: "checkout_success" });

const built = buildPaywallAttributionReport();
assert.equal(built.totalRejections, 1);
assert.equal(built.totalInterest, 1);
assert.equal(built.totalConversions, 1);
assert.ok(built.topRejectionReasons[0]?.reason === "too_expensive");

if (failures.length) {
  console.error("validate-paywall-attribution failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-paywall-attribution ok", { answer: built.mainAnswer.slice(0, 72) });
