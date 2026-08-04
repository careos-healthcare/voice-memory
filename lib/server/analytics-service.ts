import "server-only";

import { createHash } from "node:crypto";

import type { WebStripeFunnelEvent } from "@/lib/analytics/web-stripe-funnel-events";
import { logServerEvent } from "@/lib/server/structured-log";

interface FunnelEventContext {
  source: "web_landing" | "stripe_checkout" | "stripe_webhook";
  userId?: string;
  checkoutSessionId?: string;
  stripeEventId?: string;
}

export function trackWebStripeFunnelEvent(
  eventName: WebStripeFunnelEvent,
  context: FunnelEventContext,
): void {
  logServerEvent("conversion_funnel", {
    eventName,
    source: context.source,
    userIdHash: context.userId ? hashIdentifier(context.userId) : undefined,
    checkoutSessionId: context.checkoutSessionId,
    stripeEventId: context.stripeEventId,
  });
}

function hashIdentifier(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}
