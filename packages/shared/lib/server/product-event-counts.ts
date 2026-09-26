import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

const memoryCounts = globalThis as typeof globalThis & {
  __thoughtprintProductEventCounts?: Map<string, number>;
};

function dayKey(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function bucket(): Map<string, number> {
  if (!memoryCounts.__thoughtprintProductEventCounts) {
    memoryCounts.__thoughtprintProductEventCounts = new Map();
  }
  return memoryCounts.__thoughtprintProductEventCounts;
}

/** Increments a daily count for an event name. Stores no payload and no user id. */
export async function recordAggregateProductEvent(eventName: string): Promise<void> {
  const key = `${dayKey()}:${eventName}`;
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO product_event_counts (event_name, day_key, event_count)
       VALUES ($1, $2, 1)
       ON CONFLICT (event_name, day_key)
       DO UPDATE SET event_count = product_event_counts.event_count + 1`,
      [eventName, dayKey()],
    );
    return;
  }
  bucket().set(key, (bucket().get(key) ?? 0) + 1);
}
