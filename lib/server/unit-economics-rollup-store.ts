import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { DailySubjectRollup } from "@/lib/server/unit-economics-domain";

const globalRollups = globalThis as typeof globalThis & {
  __vmUnitEconomicsRollups?: Map<string, DailySubjectRollup>;
};

function rollups(): Map<string, DailySubjectRollup> {
  if (!globalRollups.__vmUnitEconomicsRollups) {
    globalRollups.__vmUnitEconomicsRollups = new Map();
  }
  return globalRollups.__vmUnitEconomicsRollups;
}

function key(subjectKey: string, day: string): string {
  return `${subjectKey}\0${day}`;
}

export async function writeDailySubjectRollup(row: DailySubjectRollup): Promise<void> {
  if (!shouldUsePostgresStorage()) {
    rollups().set(key(row.subjectKey, row.day), { ...row });
    return;
  }
  await dbQuery(
    `INSERT INTO ue_daily_subject_rollups
     (subject_key, subject_key_version, day, revenue_micro_usd, credits_micro_usd,
      adjustments_micro_usd, ai_cogs_micro_usd, transcription_cogs_micro_usd,
      storage_cogs_micro_usd, bandwidth_cogs_micro_usd, live_cogs_micro_usd,
      image_cogs_micro_usd, total_cogs_micro_usd, contribution_margin_micro_usd,
      margin_bps, reconciled_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,now())
     ON CONFLICT (subject_key, day) DO UPDATE SET
       subject_key_version=EXCLUDED.subject_key_version,
       revenue_micro_usd=EXCLUDED.revenue_micro_usd,
       credits_micro_usd=EXCLUDED.credits_micro_usd,
       adjustments_micro_usd=EXCLUDED.adjustments_micro_usd,
       ai_cogs_micro_usd=EXCLUDED.ai_cogs_micro_usd,
       transcription_cogs_micro_usd=EXCLUDED.transcription_cogs_micro_usd,
       storage_cogs_micro_usd=EXCLUDED.storage_cogs_micro_usd,
       bandwidth_cogs_micro_usd=EXCLUDED.bandwidth_cogs_micro_usd,
       live_cogs_micro_usd=EXCLUDED.live_cogs_micro_usd,
       image_cogs_micro_usd=EXCLUDED.image_cogs_micro_usd,
       total_cogs_micro_usd=EXCLUDED.total_cogs_micro_usd,
       contribution_margin_micro_usd=EXCLUDED.contribution_margin_micro_usd,
       margin_bps=EXCLUDED.margin_bps,
       reconciled_at=now()`,
    [
      row.subjectKey, row.subjectKeyVersion, row.day, row.revenueMicroUsd.toString(),
      row.creditsMicroUsd.toString(), row.adjustmentsMicroUsd.toString(),
      row.aiCogsMicroUsd.toString(), row.transcriptionCogsMicroUsd.toString(),
      row.storageCogsMicroUsd.toString(), row.bandwidthCogsMicroUsd.toString(),
      row.liveCogsMicroUsd.toString(), row.imageCogsMicroUsd.toString(),
      row.totalCogsMicroUsd.toString(), row.contributionMarginMicroUsd.toString(),
      row.marginBps,
    ],
  );
}

export async function readDailySubjectRollup(
  subjectKey: string,
  day: string,
): Promise<DailySubjectRollup | null> {
  if (!shouldUsePostgresStorage()) return rollups().get(key(subjectKey, day)) ?? null;
  const result = await dbQuery<Record<string, string | number | Date | null>>(
    `SELECT * FROM ue_daily_subject_rollups WHERE subject_key = $1 AND day = $2`,
    [subjectKey, day],
  );
  const row = result.rows[0];
  if (!row) return null;
  const amount = (name: string) => BigInt(String(row[name]));
  return {
    subjectKey: String(row.subject_key),
    subjectKeyVersion: Number(row.subject_key_version),
    day: row.day instanceof Date
      ? row.day.toISOString().slice(0, 10)
      : String(row.day).slice(0, 10),
    revenueMicroUsd: amount("revenue_micro_usd"),
    creditsMicroUsd: amount("credits_micro_usd"),
    adjustmentsMicroUsd: amount("adjustments_micro_usd"),
    aiCogsMicroUsd: amount("ai_cogs_micro_usd"),
    transcriptionCogsMicroUsd: amount("transcription_cogs_micro_usd"),
    storageCogsMicroUsd: amount("storage_cogs_micro_usd"),
    bandwidthCogsMicroUsd: amount("bandwidth_cogs_micro_usd"),
    liveCogsMicroUsd: amount("live_cogs_micro_usd"),
    imageCogsMicroUsd: amount("image_cogs_micro_usd"),
    totalCogsMicroUsd: amount("total_cogs_micro_usd"),
    contributionMarginMicroUsd: amount("contribution_margin_micro_usd"),
    marginBps: row.margin_bps === null ? null : Number(row.margin_bps),
  };
}

export interface EconomicsAggregateReport {
  subjectCount: number;
  dayCount: number;
  revenueMicroUsd: bigint;
  creditsMicroUsd: bigint;
  adjustmentsMicroUsd: bigint;
  aiCogsMicroUsd: bigint;
  transcriptionCogsMicroUsd: bigint;
  storageCogsMicroUsd: bigint;
  bandwidthCogsMicroUsd: bigint;
  liveCogsMicroUsd: bigint;
  imageCogsMicroUsd: bigint;
  totalCogsMicroUsd: bigint;
  contributionMarginMicroUsd: bigint;
}

export async function aggregateDailyRollups(
  fromDay: string,
  toDay: string,
  subjectKey?: string,
): Promise<EconomicsAggregateReport> {
  if (!shouldUsePostgresStorage()) {
    return aggregateRows([...rollups().values()].filter((row) =>
      row.day >= fromDay && row.day <= toDay &&
      (!subjectKey || row.subjectKey === subjectKey)));
  }
  const result = await dbQuery<Record<string, string>>(
    `SELECT COUNT(DISTINCT subject_key)::text AS subject_count,
            COUNT(DISTINCT day)::text AS day_count,
            COALESCE(SUM(revenue_micro_usd),0)::text AS revenue,
            COALESCE(SUM(credits_micro_usd),0)::text AS credits,
            COALESCE(SUM(adjustments_micro_usd),0)::text AS adjustments,
            COALESCE(SUM(ai_cogs_micro_usd),0)::text AS ai,
            COALESCE(SUM(transcription_cogs_micro_usd),0)::text AS transcription,
            COALESCE(SUM(storage_cogs_micro_usd),0)::text AS storage,
            COALESCE(SUM(bandwidth_cogs_micro_usd),0)::text AS bandwidth,
            COALESCE(SUM(live_cogs_micro_usd),0)::text AS live,
            COALESCE(SUM(image_cogs_micro_usd),0)::text AS image,
            COALESCE(SUM(total_cogs_micro_usd),0)::text AS total,
            COALESCE(SUM(contribution_margin_micro_usd),0)::text AS margin
     FROM ue_daily_subject_rollups
     WHERE day >= $1 AND day <= $2 AND ($3::text IS NULL OR subject_key = $3)`,
    [fromDay, toDay, subjectKey ?? null],
  );
  const row = result.rows[0];
  return {
    subjectCount: Number(row?.subject_count ?? 0),
    dayCount: Number(row?.day_count ?? 0),
    revenueMicroUsd: BigInt(row?.revenue ?? 0),
    creditsMicroUsd: BigInt(row?.credits ?? 0),
    adjustmentsMicroUsd: BigInt(row?.adjustments ?? 0),
    aiCogsMicroUsd: BigInt(row?.ai ?? 0),
    transcriptionCogsMicroUsd: BigInt(row?.transcription ?? 0),
    storageCogsMicroUsd: BigInt(row?.storage ?? 0),
    bandwidthCogsMicroUsd: BigInt(row?.bandwidth ?? 0),
    liveCogsMicroUsd: BigInt(row?.live ?? 0),
    imageCogsMicroUsd: BigInt(row?.image ?? 0),
    totalCogsMicroUsd: BigInt(row?.total ?? 0),
    contributionMarginMicroUsd: BigInt(row?.margin ?? 0),
  };
}

function aggregateRows(rows: DailySubjectRollup[]): EconomicsAggregateReport {
  const result: EconomicsAggregateReport = {
    subjectCount: new Set(rows.map((row) => row.subjectKey)).size,
    dayCount: new Set(rows.map((row) => row.day)).size,
    revenueMicroUsd: 0n, creditsMicroUsd: 0n, adjustmentsMicroUsd: 0n,
    aiCogsMicroUsd: 0n, transcriptionCogsMicroUsd: 0n, storageCogsMicroUsd: 0n,
    bandwidthCogsMicroUsd: 0n, liveCogsMicroUsd: 0n, imageCogsMicroUsd: 0n,
    totalCogsMicroUsd: 0n, contributionMarginMicroUsd: 0n,
  };
  for (const row of rows) {
    result.revenueMicroUsd += row.revenueMicroUsd;
    result.creditsMicroUsd += row.creditsMicroUsd;
    result.adjustmentsMicroUsd += row.adjustmentsMicroUsd;
    result.aiCogsMicroUsd += row.aiCogsMicroUsd;
    result.transcriptionCogsMicroUsd += row.transcriptionCogsMicroUsd;
    result.storageCogsMicroUsd += row.storageCogsMicroUsd;
    result.bandwidthCogsMicroUsd += row.bandwidthCogsMicroUsd;
    result.liveCogsMicroUsd += row.liveCogsMicroUsd;
    result.imageCogsMicroUsd += row.imageCogsMicroUsd;
    result.totalCogsMicroUsd += row.totalCogsMicroUsd;
    result.contributionMarginMicroUsd += row.contributionMarginMicroUsd;
  }
  return result;
}

export function resetUnitEconomicsRollupMemoryForTests(): void {
  rollups().clear();
}
