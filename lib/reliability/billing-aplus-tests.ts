import assert from "node:assert/strict";
import { createHmac } from "node:crypto";

import Stripe from "stripe";

import {
  handleStripeSubscription,
  processStripeWebhookEvent,
} from "@/lib/billing/stripe-webhook-handler";
import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import {
  getServerBillingRecord,
  resolveServerEntitlements,
  revokeServerBilling,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";
import { claimStripeWebhookEvent } from "@/lib/server/webhook-idempotency";

function mockSubscription(
  userId: string,
  status: Stripe.Subscription.Status,
): Stripe.Subscription {
  return {
    id: "sub_test_1",
    object: "subscription",
    metadata: { userId },
    customer: "cus_test",
    status,
    items: { object: "list", data: [], has_more: false, url: "" },
  } as unknown as Stripe.Subscription;
}

export async function runBillingAplusTests(): Promise<{
  failures: string[];
  liveStripeProofRequired: boolean;
  envReady: boolean;
  webhookProven: boolean;
}> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("payment_failed does not grant pro", async () => {
    const userId = `billing-aplus-fail-${Date.now()}`;
    await upsertServerBillingRecord({ userId, status: "active", tier: "pro" });
    const event = {
      id: `evt_fail_${Date.now()}`,
      type: "invoice.payment_failed",
      data: { object: { metadata: { userId } } },
    } as unknown as Stripe.Event;
    await processStripeWebhookEvent(event, async () => mockSubscription(userId, "active"));
    const ent = await resolveServerEntitlements(userId);
    assert.equal(ent.tier, "free");
    await revokeServerBilling(userId);
  });

  await check("checkout.session.completed grants pro", async () => {
    const userId = `billing-aplus-checkout-${Date.now()}`;
    const event = {
      id: `evt_co_${Date.now()}`,
      type: "checkout.session.completed",
      data: {
        object: {
          metadata: {},
          client_reference_id: userId,
          subscription: "sub_test_1",
        },
      },
    } as unknown as Stripe.Event;
    await processStripeWebhookEvent(event, async () => mockSubscription(userId, "active"));
    const ent = await resolveServerEntitlements(userId);
    assert.equal(ent.tier, "pro");
    await revokeServerBilling(userId);
  });

  await check("active subscription grants pro", async () => {
    const userId = `billing-aplus-active-${Date.now()}`;
    await handleStripeSubscription(mockSubscription(userId, "active"), "active");
    const ent = await resolveServerEntitlements(userId);
    assert.equal(ent.tier, "pro");
    await revokeServerBilling(userId);
  });

  await check("canceled revokes pro", async () => {
    const userId = `billing-aplus-cancel-${Date.now()}`;
    await handleStripeSubscription(mockSubscription(userId, "active"), "active");
    await handleStripeSubscription(mockSubscription(userId, "canceled"), "canceled");
    const ent = await resolveServerEntitlements(userId);
    assert.equal(ent.tier, "free");
  });

  await check("subscription deleted revokes pro", async () => {
    const userId = `billing-aplus-deleted-${Date.now()}`;
    await handleStripeSubscription(mockSubscription(userId, "active"), "active");
    const event = {
      id: `evt_del_${Date.now()}`,
      type: "customer.subscription.deleted",
      data: { object: { metadata: { userId }, id: "sub_test_1", customer: "cus_test" } },
    } as unknown as Stripe.Event;
    await processStripeWebhookEvent(event, async () => mockSubscription(userId, "canceled"));
    const ent = await resolveServerEntitlements(userId);
    assert.equal(ent.tier, "free");
  });

  await check("duplicate webhook idempotent", async () => {
    const eventId = `evt_dup_${Date.now()}`;
    assert.equal(await claimStripeWebhookEvent(eventId), true);
    assert.equal(await claimStripeWebhookEvent(eventId), false);
  });

  await check("webhook signature roundtrip", () => {
    const secret = "whsec_aplus_test_secret_value_here";
    const payload = JSON.stringify({ id: "evt_sig", type: "ping" });
    const ts = Math.floor(Date.now() / 1000);
    const sig = createHmac("sha256", secret).update(`${ts}.${payload}`).digest("hex");
    const stripe = new Stripe("sk_test_aplus");
    const event = stripe.webhooks.constructEvent(payload, `t=${ts},v1=${sig}`, secret);
    assert.equal(event.id, "evt_sig");
  });

  await check("billing disabled when stripe env missing", () => {
    const saved = { ...process.env };
    for (const k of [
      "STRIPE_SECRET_KEY",
      "STRIPE_WEBHOOK_SECRET",
      "STRIPE_PRO_PRICE_ID",
      "NEXT_PUBLIC_APP_URL",
    ] as const) {
      delete process.env[k];
    }
    assert.equal(getStripeBillingConfig().enabled, false);
    assert.equal(isLiveBillingAvailable(), false);
    Object.assign(process.env, saved);
  });

  const envReady = getStripeBillingConfig().enabled;
  const webhookProven = process.env.STRIPE_WEBHOOK_LIVE_PROOF === "1";
  const liveStripeProofRequired = !envReady || !webhookProven;

  return { failures, liveStripeProofRequired, envReady, webhookProven };
}
