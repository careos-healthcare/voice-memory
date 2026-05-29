import assert from "node:assert/strict";

import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import { getPaymentStackAudit, isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import {
  resolveServerEntitlements,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";

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
  } finally {
    for (const key of envKeys) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  }

  return { failures };
}
