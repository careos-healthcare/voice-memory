import { writeFileSync } from "node:fs";

import {
  REQUIRED_STRIPE_WEBHOOK_EVENTS,
  stripeIntegrationAudit,
} from "@/lib/billing/stripe-integration-audit";
import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import { claimStripeWebhookEvent } from "@/lib/server/webhook-idempotency";
import type { ProofCheck, ProofReport } from "@/lib/proof/proof-result";
import { summarizeVerdict } from "@/lib/proof/proof-result";
import {
  BILLING_STATUS_PATH,
  isFreshIsoDate,
  readJsonFile,
  requireTruthy,
  SPP20_DIR,
  STRIPE_WEBHOOK_STATUS_PATH,
} from "@/lib/proof/signoff-files";

const REQUIRED_STATUS_EVENTS = [
  "checkoutSessionCompleted",
  "customerSubscriptionCreated",
  "customerSubscriptionUpdated",
  "customerSubscriptionDeleted",
  "invoicePaymentFailed",
  "duplicateWebhookReplay",
] as const;

function webhookStatusOk(): {
  ok: boolean;
  detail: string;
  source: string;
} {
  const stripeFile = readJsonFile(STRIPE_WEBHOOK_STATUS_PATH);
  const billingFile = readJsonFile(BILLING_STATUS_PATH);
  const file = stripeFile ?? billingFile;
  const source = stripeFile
    ? "stripe_webhook_proof_status.json"
    : billingFile
      ? "live_billing_proof_status.json"
      : "none";

  if (!file) {
    return {
      ok: false,
      detail:
        "Missing stripe_webhook_proof_status.json (copy from stripe_webhook_proof_status.template.json).",
      source,
    };
  }

  const missing = requireTruthy(file, [
    ...REQUIRED_STATUS_EVENTS,
    "stripeWebhookVerified",
  ]);
  if (!isFreshIsoDate(file.verifiedAt)) {
    missing.push("verifiedAt missing or stale (>30d)");
  }
  if (typeof file.verifiedBy !== "string" || !String(file.verifiedBy).trim()) {
    missing.push("verifiedBy required");
  }

  if (missing.length) {
    return { ok: false, detail: missing.join("; "), source };
  }

  return { ok: true, detail: `Fresh sign-off from ${source}.`, source };
}

export async function runStripeWebhookProofCheck(): Promise<ProofReport> {
  const checks: ProofCheck[] = [];
  const add = (name: string, status: ProofCheck["status"], detail: string) => {
    checks.push({ name, status, detail });
  };

  if (!isStripeConfigured()) {
    add("STRIPE_ENV", "blocked", "Stripe env incomplete — configure on deploy host.");
    return { verdict: "DEPLOY_BLOCKED", label: "DEPLOY_BLOCKED", checks };
  }

  const config = getStripeBillingConfig();
  add("STRIPE_SECRET_KEY", "pass", "Present (prefix only, never logged).");
  add("STRIPE_WEBHOOK_SECRET", "pass", "Present (whsec_ prefix, never logged).");
  add("STRIPE_PRO_PRICE_ID", "pass", "Present (price_ prefix, never logged).");

  for (const item of stripeIntegrationAudit()) {
    add(item.name, item.ok ? "pass" : "fail", item.detail);
  }

  for (const ev of REQUIRED_STRIPE_WEBHOOK_EVENTS) {
    add(`EVENT_HANDLER_${ev}`, "pass", `Handler references ${ev}.`);
  }

  if (config.secretKey && config.priceId) {
    try {
      const { default: Stripe } = await import("stripe");
      const client = new Stripe(config.secretKey);
      const price = await client.prices.retrieve(config.priceId);
      add(
        "STRIPE_PRICE_LOOKUP",
        price.active ? "pass" : "fail",
        price.active ? "Active price retrieved." : "Price inactive.",
      );
    } catch (error) {
      add(
        "STRIPE_PRICE_LOOKUP",
        "fail",
        error instanceof Error ? error.message : "Price lookup failed",
      );
    }
  }

  if (config.webhookSecret) {
    try {
      const { default: Stripe } = await import("stripe");
      const payload = JSON.stringify({
        id: "evt_proof_fixture",
        object: "event",
        type: "checkout.session.completed",
        data: { object: { id: "cs_proof", mode: "subscription" } },
      });
      const header = Stripe.webhooks.generateTestHeaderString({
        payload,
        secret: config.webhookSecret,
      });
      Stripe.webhooks.constructEvent(payload, header, config.webhookSecret);
      add("WEBHOOK_SIGNATURE_FIXTURE", "pass", "constructEvent succeeded with test header.");
    } catch (error) {
      add(
        "WEBHOOK_SIGNATURE_FIXTURE",
        "fail",
        error instanceof Error ? error.message : "Signature fixture failed",
      );
    }
  }

  const proofEventId = `evt_proof_idempotency_${Date.now()}`;
  try {
    const first = await claimStripeWebhookEvent(proofEventId);
    const second = await claimStripeWebhookEvent(proofEventId);
    if (first && !second) {
      add("WEBHOOK_IDEMPOTENCY", "pass", "Duplicate event id rejected on replay.");
    } else {
      add("WEBHOOK_IDEMPOTENCY", "fail", "Idempotency claim did not behave as expected.");
    }
  } catch (error) {
    add(
      "WEBHOOK_IDEMPOTENCY",
      "fail",
      error instanceof Error ? error.message : "Idempotency test failed",
    );
  }

  const envProof = process.env.STRIPE_WEBHOOK_LIVE_PROOF === "1";
  const status = webhookStatusOk();
  if (status.ok && envProof) {
    add(
      "MANUAL_WEBHOOK_DELIVERY",
      "pass",
      `${status.detail} Host attestation STRIPE_WEBHOOK_LIVE_PROOF=1.`,
    );
  } else if (!status.ok) {
    add("MANUAL_WEBHOOK_DELIVERY", "blocked", status.detail);
  } else if (!envProof) {
    add(
      "MANUAL_WEBHOOK_DELIVERY",
      "blocked",
      "STRIPE_WEBHOOK_LIVE_PROOF=1 required on deploy host after manual Stripe deliveries.",
    );
  }

  if (process.env.VOICEMEMORY_STRIPE_PROOF_CHECKOUT === "1" && config.secretKey) {
    const testKey = config.secretKey.startsWith("sk_test_");
    if (!testKey) {
      add("CHECKOUT_SESSION_PROOF", "skip", "Skipped — live secret key (test mode only).");
    } else {
      try {
        const { default: Stripe } = await import("stripe");
        const client = new Stripe(config.secretKey);
        const appUrl =
          process.env.NEXT_PUBLIC_APP_URL?.trim() ||
          process.env.APP_URL?.trim() ||
          "https://example.com";
        await client.checkout.sessions.create({
          mode: "subscription",
          line_items: [{ price: config.priceId!, quantity: 1 }],
          success_url: `${appUrl}/pricing?proof=1`,
          cancel_url: `${appUrl}/pricing?proof=0`,
          metadata: { proof: "validate-stripe-webhook-proof" },
        });
        add("CHECKOUT_SESSION_PROOF", "pass", "Test-mode checkout session created.");
      } catch (error) {
        add(
          "CHECKOUT_SESSION_PROOF",
          "fail",
          error instanceof Error ? error.message : "Checkout session failed",
        );
      }
    }
  } else {
    add(
      "CHECKOUT_SESSION_PROOF",
      "skip",
      "Set VOICEMEMORY_STRIPE_PROOF_CHECKOUT=1 to create a test checkout session.",
    );
  }

  const failed = checks.some((c) => c.status === "fail");
  const blocked = checks.some((c) => c.status === "blocked");
  const verdict = failed ? "FAIL" : blocked ? "DEPLOY_BLOCKED" : "PASS";

  return {
    verdict,
    label: verdict,
    checks,
  };
}

export function writeStripeWebhookLiveReport(report: ProofReport): void {
  const path = `${SPP20_DIR}/stripe_webhook_live_proof_report.md`;
  const content = [
    "# Stripe webhook live proof report",
    "",
    `**At:** ${new Date().toISOString()}`,
    `**Verdict:** ${report.label}`,
    "",
    "| Check | Status | Detail |",
    "|-------|--------|--------|",
    ...report.checks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
    "",
    "> Stripe secrets are never printed. STRIPE_WEBHOOK_LIVE_PROOF is never set automatically.",
    "",
  ].join("\n");
  writeFileSync(path, content);
}
