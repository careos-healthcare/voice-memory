import assert from "node:assert/strict";
import { createHmac } from "node:crypto";

import Stripe from "stripe";

import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import {
  resolveServerEntitlements,
  upsertServerBillingRecord,
  revokeServerBilling,
} from "@/lib/server/billing-entitlements";
import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";

export async function runBillingProductionTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("missing stripe env fails closed", () => {
    const saved = process.env.STRIPE_SECRET_KEY;
    delete process.env.STRIPE_SECRET_KEY;
    assert.equal(getStripeBillingConfig().enabled, false);
    if (saved) process.env.STRIPE_SECRET_KEY = saved;
  });

  await check("no entitlement defaults free", async () => {
    const free = await resolveServerEntitlements("billing-gate-free");
    assert.equal(free.tier, "free");
    assert.equal(free.source, "free_tier");
  });

  await check("active entitlement grants pro", async () => {
    await upsertServerBillingRecord({
      userId: "billing-gate-paid",
      status: "active",
      tier: "pro",
    });
    const paid = await resolveServerEntitlements("billing-gate-paid");
    assert.equal(paid.tier, "pro");
    assert.ok(paid.entitlements.includes("open_loops"));
  });

  await check("canceled entitlement revokes pro", async () => {
    await revokeServerBilling("billing-gate-paid");
    const free = await resolveServerEntitlements("billing-gate-paid");
    assert.equal(free.tier, "free");
  });

  await check("live billing flag when stripe env complete", () => {
    const saved: Record<string, string | undefined> = {};
    for (const k of [
      "STRIPE_SECRET_KEY",
      "STRIPE_WEBHOOK_SECRET",
      "STRIPE_PRO_PRICE_ID",
      "NEXT_PUBLIC_APP_URL",
    ] as const) {
      saved[k] = process.env[k];
      process.env[k] =
        k === "STRIPE_SECRET_KEY"
          ? "sk_test_12345678901234567890123456789012"
          : k === "STRIPE_WEBHOOK_SECRET"
            ? "whsec_test_12345678901234567890123456789012"
            : k === "STRIPE_PRO_PRICE_ID"
              ? "price_test"
              : "https://example.com";
    }
    assert.equal(isLiveBillingAvailable(), true);
    for (const k of Object.keys(saved)) {
      const key = k as keyof typeof saved;
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  });

  await check("webhook signature verification", () => {
    const secret = "whsec_test_secret_for_unit_tests_only";
    const payload = JSON.stringify({ id: "evt_test", type: "ping" });
    const timestamp = Math.floor(Date.now() / 1000);
    const signed = createHmac("sha256", secret)
      .update(`${timestamp}.${payload}`)
      .digest("hex");
    const header = `t=${timestamp},v1=${signed}`;
    const stripe = new Stripe("sk_test_123");
    const event = stripe.webhooks.constructEvent(payload, header, secret);
    assert.equal(event.id, "evt_test");
  });

  return { failures };
}
