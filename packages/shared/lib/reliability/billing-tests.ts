import assert from "node:assert/strict";

import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import { getPaymentStackAudit, isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import {
  resolveServerEntitlements,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";
import {
  rememberWebhookEventCreatedAt,
  shouldApplyBillingWebhookUpdate,
} from "@/lib/server/billing-webhook-ordering";
import { isRevenueCatRestConfigured } from "@/lib/server/revenuecat-rest";

export async function runBillingTestsAsync(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  const saved: Record<string, string | undefined> = {};
  const envKeys = [
    "STRIPE_SECRET_KEY",
    "STRIPE_WEBHOOK_SECRET",
    "STRIPE_PRO_PRICE_ID",
    "NEXT_PUBLIC_APP_URL",
  ] as const;

  for (const key of envKeys) {
    saved[key] = process.env[key];
    delete process.env[key];
  }

  try {
    await check("stripe disabled when env missing", () => {
      const config = getStripeBillingConfig();
      assert.equal(config.enabled, false);
      assert.equal(isStripeConfigured(), false);
      assert.equal(getPaymentStackAudit().checkoutImplemented, false);
      assert.equal(isLiveBillingAvailable(), false);
    });

    await check("server entitlements default free", async () => {
      const resolved = await resolveServerEntitlements("billing-free-user");
      assert.equal(resolved.tier, "free");
    });

    await check("active subscription grants pro", async () => {
      await upsertServerBillingRecord({
        userId: "billing-paid-user",
        status: "active",
        tier: "pro",
      });
      const paid = await resolveServerEntitlements("billing-paid-user");
      assert.equal(paid.tier, "pro");
      assert.equal(paid.source, "paid");
    });

    await check("canceled revokes pro", async () => {
      await upsertServerBillingRecord({
        userId: "billing-paid-user",
        status: "canceled",
        tier: "free",
      });
      const free = await resolveServerEntitlements("billing-paid-user");
      assert.equal(free.tier, "free");
    });

    await check("stale webhook events are ignored", async () => {
      const userId = "billing-stale-webhook-user";
      await upsertServerBillingRecord({
        userId,
        status: "active",
        tier: "pro",
        eventCreatedAt: 200,
      });
      await upsertServerBillingRecord({
        userId,
        status: "canceled",
        tier: "free",
        eventCreatedAt: 100,
      });
      const stillPro = await resolveServerEntitlements(userId);
      assert.equal(stillPro.tier, "pro");
      assert.equal(stillPro.source, "paid");
    });

    await check("shouldApplyBillingWebhookUpdate rejects stale timestamps", () => {
      rememberWebhookEventCreatedAt("billing-ordering-user", 500);
      const decision = shouldApplyBillingWebhookUpdate({
        userId: "billing-ordering-user",
        incomingStatus: "canceled",
        existingStatus: "active",
        eventCreatedAt: 400,
      });
      assert.equal(decision.apply, false);
      assert.equal(decision.reason, "stale_webhook_event");
    });

    await check("revenuecat rest fallback disabled without secret", async () => {
      assert.equal(isRevenueCatRestConfigured(), false);
      const resolved = await resolveServerEntitlements("billing-revenuecat-user");
      assert.equal(resolved.tier, "free");
      assert.equal(resolved.source, "free_tier");
    });
  } finally {
    for (const key of envKeys) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  }

  return { failures };
}
