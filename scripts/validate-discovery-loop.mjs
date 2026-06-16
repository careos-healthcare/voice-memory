#!/usr/bin/env node
/**
 * Integration audit: discover → theories → blind spots → memory loop.
 * Runs feature validators plus route/module presence checks.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const CHILD_VALIDATORS = [
  "validate:evidence-feed",
  "validate:theory-volatility",
  "validate:theory-notifications",
  "validate:notification-effectiveness",
  "validate:breakthrough-tracking",
  "validate:insight-scorecard",
  "validate:theory-resolution",
  "validate:self-recognition-ingredients",
  "validate:mini-wow",
  "validate:theory-tracker",
  "validate:blind-spot-tests",
  "validate:uncomfortably-accurate",
  "validate:insight-outcomes",
  "validate:blind-spot-quality",
  "validate:insight-ingredient-optimizer",
  "validate:archive-value-progress",
  "validate:value-moment-paywall",
  "validate:evolving-understanding",
  "validate:session-movement-summary",
  "validate:archive-asset-value",
  "validate:archive-maturity",
  "validate:hard-to-reproduce-proof",
  "validate:evidence-archive-home",
  "validate:archive-value-deepening",
];

const DISCOVERY_LOOP_MODULES = [
  "lib/discover/evidence-feed.ts",
  "lib/discover/theory-change-feed.ts",
  "lib/discover/theory-resolution-feed.ts",
  "lib/discover/theory-volatility.ts",
  "lib/discover/discover-visit.ts",
  "lib/theories/theory-notification-generator.ts",
  "lib/theories/theory-notification-storage.ts",
  "lib/theories/theory-notification-lifecycle.ts",
  "lib/theories/notification-effectiveness.ts",
  "lib/breakthrough/breakthrough-events.ts",
  "lib/breakthrough/breakthrough-tracking-report.ts",
  "lib/breakthrough/breakthrough-attribution.ts",
  "lib/insights/insight-scorecard.ts",
  "lib/insights/insight-scorecard-report.ts",
  "lib/insights/insight-outcome-storage.ts",
  "lib/insights/insight-outcome-report.ts",
  "lib/insights/insight-outcome-attribution.ts",
  "lib/theories/theory-resolution.ts",
  "lib/insights/self-recognition-ingredients.ts",
  "lib/blind-spots/mini-wow.ts",
  "lib/blind-spots/evidence-accuracy.ts",
  "lib/blind-spots/blind-spot-experiment-commitment.ts",
  "lib/blind-spots/blind-spot-experiment-followup.ts",
  "lib/blind-spots/blind-spot-experiment-metrics.ts",
  "lib/blind-spots/blind-spot-quality-storage.ts",
  "lib/blind-spots/blind-spot-quality-report.ts",
  "lib/blind-spots/blind-spot-quality-enrichment.ts",
  "components/internal/BlindSpotQualityPanel.tsx",
  "lib/insights/insight-ingredient-optimizer.ts",
  "lib/insights/insight-ingredient-optimizer-report.ts",
  "components/internal/InsightIngredientOptimizerPanel.tsx",
  "lib/product/archive-value-progress.ts",
  "lib/product/archive-value-metrics.ts",
  "components/product/ArchiveValueBanner.tsx",
  "components/internal/ArchiveValueProgressPanel.tsx",
  "lib/billing/value-moment-paywall.ts",
  "lib/billing/value-moment-paywall-metrics.ts",
  "components/billing/ValueMomentPaywall.tsx",
  "components/internal/ValueMomentPaywallPanel.tsx",
  "components/discover/TheoryChangeFeed.tsx",
  "components/discover/EvidenceFeedSection.tsx",
  "components/discover/TheoryResolutionSection.tsx",
  "components/internal/TheoryVolatilityPanel.tsx",
  "components/internal/SelfRecognitionIngredientsPanel.tsx",
  "components/blind-spots/MiniWowPanel.tsx",
  "lib/metrics/evolving-understanding-events.ts",
  "lib/metrics/evolving-understanding-report.ts",
  "components/blind-spots/WhatHappensNextPanel.tsx",
  "components/theories/EvolvingViewCard.tsx",
  "lib/archive/session-movement-summary.ts",
  "components/archive/SessionMovementSummary.tsx",
  "lib/archive/archive-maturity.ts",
  "components/archive/ArchiveMaturityMeter.tsx",
  "lib/internal/retention-moat-report.ts",
  "components/internal/RetentionMoatPanel.tsx",
];

const PRODUCT_ROUTES = [
  { href: "/discover", page: "app/discover/page.tsx" },
  { href: "/theories", page: "app/theories/page.tsx" },
  { href: "/blind-spots", page: "app/blind-spots/page.tsx" },
  { href: "/memory", page: "app/memory/page.tsx" },
];

function runNpmScript(scriptName) {
  console.log(`\n▶ npm run ${scriptName}`);
  const result = spawnSync("npm", ["run", scriptName], {
    cwd: ROOT,
    stdio: "inherit",
    env: { ...process.env, FORCE_COLOR: "1" },
  });
  if (result.status !== 0) {
    console.error(`\n✗ ${scriptName} failed (exit ${result.status ?? "unknown"})`);
    process.exit(result.status === null ? 1 : result.status);
  }
  console.log(`✓ ${scriptName}`);
}

const failures = [];

for (const rel of DISCOVERY_LOOP_MODULES) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing module: ${rel}`);
  }
}

for (const route of PRODUCT_ROUTES) {
  const pagePath = path.join(ROOT, route.page);
  if (!fs.existsSync(pagePath)) {
    failures.push(`missing route page: ${route.page} (${route.href})`);
    continue;
  }
  const src = fs.readFileSync(pagePath, "utf8");
  if (!src.includes("export default")) {
    failures.push(`${route.page} must export a default page component`);
  }
}

const memoryPage = path.join(ROOT, "app/memory/page.tsx");
if (fs.existsSync(memoryPage)) {
  const memorySrc = fs.readFileSync(memoryPage, "utf8");
  if (!memorySrc.includes("MiniWowPanel")) {
    failures.push("memory page must wire MiniWowPanel");
  }
  if (!memorySrc.includes("EvolvingViewCard")) {
    failures.push("memory page must wire EvolvingViewCard");
  }
}

const blindDiscovery = path.join(ROOT, "app/internal/blind-spot-discovery/page.tsx");
if (fs.existsSync(blindDiscovery)) {
  const src = fs.readFileSync(blindDiscovery, "utf8");
  if (!src.includes("SelfRecognitionIngredientsPanel")) {
    failures.push("blind-spot-discovery must wire SelfRecognitionIngredientsPanel");
  }
  if (!src.includes("BreakthroughTrackingPanel")) {
    failures.push("blind-spot-discovery must wire BreakthroughTrackingPanel");
  }
  if (!src.includes("InsightScorecardInternalPanel")) {
    failures.push("blind-spot-discovery must wire InsightScorecardInternalPanel");
  }
  if (!src.includes("BlindSpotExperimentLoopPanel")) {
    failures.push("blind-spot-discovery must wire BlindSpotExperimentLoopPanel");
  }
  if (!src.includes("InsightOutcomePanel")) {
    failures.push("blind-spot-discovery must wire InsightOutcomePanel");
  }
  if (!src.includes("BlindSpotQualityPanel")) {
    failures.push("blind-spot-discovery must wire BlindSpotQualityPanel");
  }
  if (!src.includes("InsightIngredientOptimizerPanel")) {
    failures.push("blind-spot-discovery must wire InsightIngredientOptimizerPanel");
  }
}

const retentionDiscovery = path.join(ROOT, "app/internal/retention-discovery/page.tsx");
if (fs.existsSync(retentionDiscovery)) {
  const src = fs.readFileSync(retentionDiscovery, "utf8");
  if (!src.includes("ArchiveValueProgressPanel")) {
    failures.push("retention-discovery must wire ArchiveValueProgressPanel");
  }
  if (!src.includes("ValueMomentPaywallPanel")) {
    failures.push("retention-discovery must wire ValueMomentPaywallPanel");
  }
  if (!src.includes("EvolvingUnderstandingPanel")) {
    failures.push("retention-discovery must wire EvolvingUnderstandingPanel");
  }
}

const theoryDiscovery = path.join(ROOT, "app/internal/theory-discovery/page.tsx");
if (fs.existsSync(theoryDiscovery)) {
  const src = fs.readFileSync(theoryDiscovery, "utf8");
  if (!src.includes("EvolvingUnderstandingPanel")) {
    failures.push("theory-discovery must wire EvolvingUnderstandingPanel");
  }
}

const theoryPanel = path.join(ROOT, "components/internal/TheoryDiscoveryPanel.tsx");
if (fs.existsSync(theoryPanel)) {
  const src = fs.readFileSync(theoryPanel, "utf8");
  if (!src.includes("TheoryVolatilityPanel")) {
    failures.push("TheoryDiscoveryPanel must render TheoryVolatilityPanel");
  }
  if (!src.includes("NotificationEffectivenessPanel")) {
    failures.push("TheoryDiscoveryPanel must render NotificationEffectivenessPanel");
  }
}

if (failures.length > 0) {
  console.error("validate-discovery-loop preflight failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-discovery-loop: preflight ok");
console.log(`Running ${CHILD_VALIDATORS.length} child validators…`);

for (const script of CHILD_VALIDATORS) {
  runNpmScript(script);
}

console.log("\n▶ npm run validate:restraint (discovery-loop surfaces)");
const restraint = spawnSync("npm", ["run", "validate:restraint"], {
  cwd: ROOT,
  stdio: "inherit",
  env: { ...process.env, RESTRAINT_SCOPE: "discovery-loop", FORCE_COLOR: "1" },
});
if (restraint.status !== 0) {
  console.error("\n✗ validate:restraint failed for discovery-loop surfaces");
  process.exit(restraint.status === null ? 1 : restraint.status);
}
console.log("✓ validate:restraint (discovery-loop surfaces)");

console.log("\nvalidate-discovery-loop ok");
