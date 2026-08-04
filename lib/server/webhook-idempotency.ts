import { createHmac } from "node:crypto";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

const memoryProcessed = globalThis as typeof globalThis & {
  __vmStripeEvents?: Set<string>;
};

function memorySet(): Set<string> {
  if (!memoryProcessed.__vmStripeEvents) memoryProcessed.__vmStripeEvents = new Set();
  return memoryProcessed.__vmStripeEvents;
}

export function stripeWebhookEventKey(eventId: string): string {
  if (!eventId.trim()) throw new Error("stripe_webhook_event_id_required");
  const key =
    process.env.STRIPE_WEBHOOK_SECRET?.trim() ||
    process.env.AUTH_SECRET?.trim() ||
    (process.env.NODE_ENV === "production"
      ? ""
      : "voicememory-stripe-webhook-test-fallback");
  if (!key) throw new Error("stripe_webhook_hmac_key_required");
  const digest = createHmac("sha256", key)
    .update("voicememory/stripe-webhook-event/v1\0", "utf8")
    .update(eventId, "utf8")
    .digest("base64url");
  return `swe:v1:${digest}`;
}

export async function isStripeWebhookEventClaimed(eventId: string): Promise<boolean> {
  const eventKey = stripeWebhookEventKey(eventId);
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{ exists: boolean }>(
      `SELECT EXISTS(
         SELECT 1 FROM stripe_webhook_events WHERE event_id = $1
       ) AS exists`,
      [eventKey],
    );
    return result.rows[0]?.exists === true;
  }
  return memorySet().has(eventKey);
}

/** Returns true if this event was newly claimed (should process). False = duplicate. */
export async function claimStripeWebhookEvent(eventId: string): Promise<boolean> {
  const eventKey = stripeWebhookEventKey(eventId);
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(
      `INSERT INTO stripe_webhook_events (event_id, processed_at)
       VALUES ($1, now())
       ON CONFLICT (event_id) DO NOTHING
       RETURNING event_id`,
      [eventKey],
    );
    return (result.rowCount ?? 0) > 0;
  }
  if (memorySet().has(eventKey)) return false;
  memorySet().add(eventKey);
  return true;
}
