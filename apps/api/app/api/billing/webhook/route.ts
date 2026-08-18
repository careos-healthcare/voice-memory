import { NextResponse } from "next/server";

import { processStripeWebhookEvent } from "@/lib/billing/stripe-webhook-handler";
import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { requireStripeClient } from "@/lib/server/stripe-client";
import { logServerEvent } from "@/lib/server/structured-log";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const config = getStripeBillingConfig();
  if (!config.enabled || !config.webhookSecret) {
    return apiErrorResponse({ code: "BILLING_DISABLED", route: "billing/webhook" });
  }

  const stripe = requireStripeClient();
  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return apiErrorResponse({ code: "WEBHOOK_MISSING_SIGNATURE", route: "billing/webhook" });
  }

  const body = await request.text();
  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, config.webhookSecret);
  } catch {
    return apiErrorResponse({ code: "WEBHOOK_INVALID_SIGNATURE", route: "billing/webhook" });
  }

  try {
    const result = await processStripeWebhookEvent(event, (id) =>
      stripe.subscriptions.retrieve(id),
    );
    logServerEvent("billing_webhook", {
      type: event.type,
      eventId: event.id,
      duplicate: result.skippedDuplicate,
    });
  } catch (error) {
    logServerEvent("billing_webhook", {
      type: event.type,
      ok: false,
      errorName: error instanceof Error ? error.name : "unknown",
    });
    return apiErrorFromException(error, {
      code: "WEBHOOK_HANDLER_FAILED",
      route: "billing/webhook",
      logEvent: "api_error",
    });
  }

  return NextResponse.json({ received: true });
}
