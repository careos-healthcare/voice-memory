import { NextResponse } from "next/server";

import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import { createHash } from "node:crypto";

import { requireStripeClient } from "@/lib/server/stripe-client";
import { getServerBillingRecord } from "@/lib/server/billing-entitlements";
import { getServerSession } from "@/lib/server/session";
import { logServerEvent } from "@/lib/server/structured-log";

export const runtime = "nodejs";

export async function POST() {
  const config = getStripeBillingConfig();
  if (!config.enabled) {
    return NextResponse.json(
      {
        error: "Billing is not configured.",
        code: "BILLING_DISABLED",
        missing: config.missing,
      },
      { status: 503 },
    );
  }

  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  try {
    const stripe = requireStripeClient();
    const existing = await getServerBillingRecord(session.userId);
    let customerId = existing?.stripeCustomerId ?? undefined;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: session.email,
        metadata: { userId: session.userId },
      });
      customerId = customer.id;
    }

    const checkout = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [{ price: config.priceId!, quantity: 1 }],
      success_url: `${config.appUrl}/pricing?checkout=success`,
      cancel_url: `${config.appUrl}/pricing?checkout=cancel`,
      client_reference_id: session.userId,
      metadata: { userId: session.userId },
      subscription_data: {
        metadata: { userId: session.userId },
      },
    });

    if (!checkout.url) {
      return NextResponse.json(
        { error: "Checkout session missing URL.", code: "CHECKOUT_FAILED" },
        { status: 500 },
      );
    }

    logServerEvent("billing_checkout", {
      type: "checkout.session.created",
      sessionId: checkout.id,
      userIdHash: createHash("sha256")
        .update(session.userId)
        .digest("hex")
        .slice(0, 16),
    });

    return NextResponse.json({ url: checkout.url, sessionId: checkout.id });
  } catch (error) {
    logServerEvent("billing_checkout", {
      type: "checkout.failed",
      ok: false,
      errorName: error instanceof Error ? error.name : "unknown",
    });
    return NextResponse.json(
      { error: "Could not start checkout.", code: "CHECKOUT_FAILED" },
      { status: 500 },
    );
  }
}
