#!/usr/bin/env node
import { runBillingProductionTests } from "../lib/reliability/billing-production-tests.ts";
import { runBillingTestsAsync } from "../lib/reliability/billing-tests.ts";
import { runBillingAplusTests } from "../lib/reliability/billing-aplus-tests.ts";
import { runStripeLiveCheck } from "../lib/billing/stripe-live-check.ts";

const failures = [];

const a = await runBillingTestsAsync();
const b = await runBillingProductionTests();
const c = await runBillingAplusTests();
failures.push(...a.failures, ...b.failures, ...c.failures);

const live = await runStripeLiveCheck();

if (!live.envConfigured) {
  console.warn(
    "Stripe env incomplete — set STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRO_PRICE_ID, NEXT_PUBLIC_APP_URL.",
  );
} else if (live.webhookProof !== "proven") {
  console.warn(
    "Stripe env OK — webhook MANUAL_PROOF_REQUIRED (see docs/STRIPE_LIVE_SETUP.md and stripe_live_integration_checklist.md).",
  );
}

if (c.liveStripeProofRequired && live.envConfigured && !c.webhookProven) {
  console.warn("Set STRIPE_WEBHOOK_LIVE_PROOF=1 after manual webhook verification.");
}

if (failures.length) {
  console.error("validate-billing failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-billing ok");
