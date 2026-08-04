import { NextResponse } from "next/server";

import { WEB_STRIPE_FUNNEL_EVENTS } from "@/lib/analytics/web-stripe-funnel-events";
import { processStripeWebhookEvent } from "@/lib/billing/stripe-webhook-handler";
import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import { requireStripeClient } from "@/lib/server/stripe-client";
import { trackWebStripeFunnelEvent } from "@/lib/server/analytics-service";
import { logServerEvent } from "@/lib/server/structured-log";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const config = getStripeBillingConfig();
  if (!config.enabled || !config.webhookSecret) {
    return NextResponse.json(
      { error: "Webhook not configured.", code: "BILLING_DISABLED" },
      { status: 503 },
    );
  }

  const stripe = requireStripeClient();
  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return NextResponse.json({ error: "Missing signature." }, { status: 400 });
  }

  const body = await request.text();
  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, config.webhookSecret);
  } catch {
    return NextResponse.json({ error: "Invalid signature." }, { status: 400 });
  }

  try {
    const result = await processStripeWebhookEvent(event, (id) =>
      stripe.subscriptions.retrieve(id),
    );
    if (
      event.type === "checkout.session.completed" &&
      !result.skippedDuplicate
    ) {
      trackWebStripeFunnelEvent(
        WEB_STRIPE_FUNNEL_EVENTS.subscriptionCompleted,
        {
          source: "stripe_webhook",
          checkoutSessionId: event.data.object.id,
          stripeEventId: event.id,
        },
      );
    }
    logServerEvent("billing_webhook", {
      type: event.type,
      duplicate: result.skippedDuplicate,
    });
  } catch (error) {
    logServerEvent("billing_webhook", {
      type: event.type,
      ok: false,
      errorName: error instanceof Error ? error.name : "unknown",
    });
    return NextResponse.json({ error: "Webhook handler failed." }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}
