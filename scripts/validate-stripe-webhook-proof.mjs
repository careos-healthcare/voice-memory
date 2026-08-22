#!/usr/bin/env node
import {
  runStripeWebhookProofCheck,
  writeStripeWebhookLiveReport,
} from "../packages/shared/lib/proof/stripe-webhook-proof-check.ts";
import { formatProofChecks } from "../packages/shared/lib/proof/proof-result.ts";

const report = await runStripeWebhookProofCheck();
formatProofChecks(report.checks);
writeStripeWebhookLiveReport(report);

console.log(`\nvalidate:stripe-webhook-proof — ${report.label}\n`);

if (report.verdict === "FAIL") process.exit(1);
if (report.verdict === "DEPLOY_BLOCKED") process.exit(2);
process.exit(0);
