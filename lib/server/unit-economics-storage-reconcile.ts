import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { recordPricedUsage } from "@/lib/server/unit-economics-engine";
import { createEconomicsSubjectKey } from "@/lib/server/unit-economics-subject-key";

export interface RawStorageFootprint {
  rawUserId: string;
  bytes: bigint;
}

export async function recordStorageFootprintRows(
  day: string,
  rows: readonly RawStorageFootprint[],
): Promise<number> {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) throw new Error("Invalid storage snapshot day.");
  const occurredAt = new Date(`${day}T23:59:59.999Z`);
  let inserted = 0;
  for (const row of rows) {
    if (!row.rawUserId || row.bytes < 0n) throw new Error("Invalid storage footprint row.");
    const subjectKey = createEconomicsSubjectKey("user", row.rawUserId);
    // Do not retain the raw identifier beyond this iteration or pass it to ledger dimensions/logs.
    if (await recordPricedUsage({
      eventParts: ["storage.snapshot", day, subjectKey],
      subjectKey,
      metric: "storage_snapshot_bytes",
      resource: "storage.snapshot",
      quantity: row.bytes,
      occurredAt,
      measurementBasis: "exact",
      dimensions: { provider: "internal" },
    })) inserted += 1;
  }
  return inserted;
}

export async function reconcileDailyStorageSnapshots(day: string): Promise<number> {
  if (!shouldUsePostgresStorage()) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("Durable storage reconciliation requires Postgres.");
    }
    return 0;
  }
  const result = await dbQuery<{ user_id: string; bytes: string }>(
    `SELECT user_id, SUM(bytes)::bigint AS bytes
     FROM (
       SELECT sb.user_id, pg_column_size(sb)::bigint AS bytes
       FROM sync_blobs AS sb
       UNION ALL
       SELECT je.user_id, pg_column_size(je)::bigint AS bytes
       FROM journal_entries AS je
     ) AS durable_rows
     GROUP BY user_id`,
  );
  return recordStorageFootprintRows(
    day,
    result.rows.map((row) => ({
      rawUserId: row.user_id,
      bytes: BigInt(row.bytes),
    })),
  );
}
