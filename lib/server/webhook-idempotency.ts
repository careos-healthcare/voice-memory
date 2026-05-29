import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

const memoryProcessed = globalThis as typeof globalThis & {
  __vmStripeEvents?: Set<string>;
};

function memorySet(): Set<string> {
  if (!memoryProcessed.__vmStripeEvents) memoryProcessed.__vmStripeEvents = new Set();
  return memoryProcessed.__vmStripeEvents;
}

/** Returns true if this event was newly claimed (should process). False = duplicate. */
export async function claimStripeWebhookEvent(eventId: string): Promise<boolean> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(
      `INSERT INTO stripe_webhook_events (event_id, processed_at)
       VALUES ($1, now())
       ON CONFLICT (event_id) DO NOTHING
       RETURNING event_id`,
      [eventId],
    );
    return (result.rowCount ?? 0) > 0;
  }
  if (memorySet().has(eventId)) return false;
  memorySet().add(eventId);
  return true;
}
