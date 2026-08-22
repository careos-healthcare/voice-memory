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
  "validate:self-recognition-ingredients",
  "validate:mini-wow",
  "validate:blind-spot",
  "validate:uncomfortably-accurate",
  "validate:insight-outcomes",
  "validate:value-moment-paywall",
  "validate:archive-asset-value",
  "validate:hard-to-reproduce-proof",
  "validate:evidence-archive-home",
];

const DISCOVERY_LOOP_MODULES = [
  "packages/shared/lib/discover/evidence-feed.ts",
  "packages/shared/lib/discover/theory-change-feed.ts",
  "packages/shared/lib/discover/theory-resolution-feed.ts",
  "packages/shared/lib/discover/theory-volatility.ts",
  "packages/shared/lib/discover/discover-visit.ts",
  "packages/shared/lib/theories/theory-notification-generator.ts",
  "packages/shared/lib/theories/theory-notification-storage.ts",
  "packages/shared/lib/theories/theory-notification-lifecycle.ts",
  "packages/shared/lib/theories/notification-effectiveness.ts",
  "packages/shared/lib/breakthrough/breakthrough-events.ts",
  "packages/shared/lib/breakthrough/breakthrough-tracking-report.ts",
  "packages/shared/lib/breakthrough/breakthrough-attribution.ts",
  "packages/shared/lib/insights/insight-scorecard.ts",
  "packages/shared/lib/insights/insight-scorecard-report.ts",
  "packages/shared/lib/insights/insight-outcome-storage.ts",
  "packages/shared/lib/insights/insight-outcome-report.ts",
  "packages/shared/lib/insights/insight-outcome-attribution.ts",
  "packages/shared/lib/theories/theory-resolution.ts",
  "packages/shared/lib/insights/self-recognition-ingredients.ts",
  "packages/shared/lib/blind-spots/mini-wow.ts",
  "packages/shared/lib/blind-spots/evidence-accuracy.ts",
  "packages/shared/lib/blind-spots/blind-spot-experiment-commitment.ts",
  "packages/shared/lib/blind-spots/blind-spot-experiment-followup.ts",
  "packages/shared/lib/blind-spots/blind-spot-experiment-metrics.ts",
  "packages/shared/lib/blind-spots/blind-spot-quality-storage.ts",
  "packages/shared/lib/blind-spots/blind-spot-quality-report.ts",
  "packages/shared/lib/blind-spots/blind-spot-quality-enrichment.ts",
  "apps/web/components/internal/BlindSpotQualityPanel.tsx",
  "packages/shared/lib/insights/insight-ingredient-optimizer.ts",
  "packages/shared/lib/insights/insight-ingredient-optimizer-report.ts",
  "apps/web/components/internal/InsightIngredientOptimizerPanel.tsx",
  "packages/shared/lib/product/archive-value-progress.ts",
  "packages/shared/lib/product/archive-value-metrics.ts",
  "apps/web/components/product/ArchiveValueBanner.tsx",
  "apps/web/components/internal/ArchiveValueProgressPanel.tsx",
  "packages/shared/lib/billing/value-moment-paywall.ts",
  "packages/shared/lib/billing/value-moment-paywall-metrics.ts",
  "apps/web/components/billing/ValueMomentPaywall.tsx",
  "apps/web/components/internal/ValueMomentPaywallPanel.tsx",
  "apps/web/components/discover/TheoryChangeFeed.tsx",
  "apps/web/components/discover/EvidenceFeedSection.tsx",
  "apps/web/components/discover/TheoryResolutionSection.tsx",
  "apps/web/components/internal/TheoryVolatilityPanel.tsx",
  "apps/web/components/internal/SelfRecognitionIngredientsPanel.tsx",
  "apps/web/components/blind-spots/MiniWowPanel.tsx",
  "packages/shared/lib/metrics/evolving-understanding-events.ts",
  "packages/shared/lib/metrics/evolving-understanding-report.ts",
  "apps/web/components/blind-spots/WhatHappensNextPanel.tsx",
  "apps/web/components/theories/EvolvingViewCard.tsx",
  "packages/shared/lib/archive/session-movement-summary.ts",
  "apps/web/components/archive/SessionMovementSummary.tsx",
  "packages/shared/lib/archive/archive-maturity.ts",
  "apps/web/components/archive/ArchiveMaturityMeter.tsx",
  "packages/shared/lib/internal/retention-moat-report.ts",
  "apps/web/components/internal/RetentionMoatPanel.tsx",
];

const PRODUCT_ROUTES = [
  { href: "/discover", page: "apps/web/app/discover/page.tsx" },
  { href: "/theories", page: "apps/web/app/theories/page.tsx" },
  { href: "/blind-spots", page: "apps/web/app/blind-spots/page.tsx" },
  { href: "/memory", page: "apps/web/app/memory/page.tsx" },
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

const memoryPage = path.join(ROOT, "apps/web/app/memory/page.tsx");
if (fs.existsSync(memoryPage)) {
  const memorySrc = fs.readFileSync(memoryPage, "utf8");
  if (!memorySrc.includes("MiniWowPanel")) {
    failures.push("memory page must wire MiniWowPanel");
  }
  if (!memorySrc.includes("EvolvingViewCard")) {
    failures.push("memory page must wire EvolvingViewCard");
  }
}

const blindDiscovery = path.join(ROOT, "apps/web/app/internal/blind-spot-discovery/page.tsx");
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

const retentionDiscovery = path.join(ROOT, "apps/web/app/internal/retention-discovery/page.tsx");
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

const theoryDiscovery = path.join(ROOT, "apps/web/app/internal/theory-discovery/page.tsx");
if (fs.existsSync(theoryDiscovery)) {
  const src = fs.readFileSync(theoryDiscovery, "utf8");
  if (!src.includes("EvolvingUnderstandingPanel")) {
    failures.push("theory-discovery must wire EvolvingUnderstandingPanel");
  }
}

const theoryPanel = path.join(ROOT, "apps/web/components/internal/TheoryDiscoveryPanel.tsx");
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
