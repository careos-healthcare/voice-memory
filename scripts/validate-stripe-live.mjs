#!/usr/bin/env node
/**
 * Live/staging Stripe env + integration check. Never prints secret values.
 *
 * Exit 0 — env + code integration OK (webhook may still need manual proof)
 * Exit 1 — code integration failure
 * Exit 2 — Stripe env incomplete (deploy-blocked)
 */
import {
  formatStripeLiveReport,
  runStripeLiveCheck,
  writeStripeLiveReport,
} from "../packages/shared/lib/billing/stripe-live-check.ts";

const retrievePrice = process.argv.includes("--retrieve-price");
const strictEnv = process.argv.includes("--strict-env");

const report = await runStripeLiveCheck({ retrievePrice });

for (const check of report.checks) {
  const label = check.status.toUpperCase().padEnd(6);
  console.log(`${label} ${check.name}: ${check.detail}`);
}

writeStripeLiveReport(report);

console.log("\n---");
console.log(`Env configured: ${report.envConfigured}`);
console.log(`Code integration: ${report.codeIntegrationOk ? "PASS" : "FAIL"}`);
console.log(
  `Webhook proof: ${report.webhookProof === "proven" ? "PROVEN" : "MANUAL_PROOF_REQUIRED"}`,
);
if (report.webhookProof !== "proven") {
  console.log(
    "After Stripe CLI/dashboard test, set STRIPE_WEBHOOK_LIVE_PROOF=1 and re-run.",
  );
}

const reportPaths = [
  `${process.env.HOME ?? ""}/Desktop/spp20/stripe_live_integration_report.md`,
  "docs/reports/stripe_live_integration_report.md",
];
console.log(`Report written: ${reportPaths.filter(Boolean).join(", ")}`);

if (!report.codeIntegrationOk) {
  console.error("\nvalidate:stripe-live FAILED — code integration\n");
  process.exit(1);
}

if (strictEnv && !report.envConfigured) {
  console.warn("\nvalidate:stripe-live — env incomplete (deploy-blocked)\n");
  process.exit(2);
}

if (!report.envConfigured) {
  console.warn("\nvalidate:stripe-live — code OK; Stripe env not set in this shell.\n");
} else if (report.webhookProof !== "proven") {
  console.warn("\nvalidate:stripe-live — env OK; webhook MANUAL_PROOF_REQUIRED.\n");
} else {
  console.log("\nvalidate:stripe-live ok — env, code, and webhook proof.\n");
}

process.exit(0);
