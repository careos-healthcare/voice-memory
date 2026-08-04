import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { DailySubjectRollup } from "@/lib/server/unit-economics-domain";
import {
  createEconomicsBreachDedupKey,
  createEconomicsBreachKey,
} from "@/lib/server/unit-economics-subject-key";

export type BreachThresholdCode =
  | "negative_margin"
  | "low_margin_bps"
  | "high_daily_cogs"
  | "absolute_loss";
export type BreachStatus = "open" | "acknowledged" | "resolved";

export interface ThresholdBreach {
  breachKey: string;
  dedupKey: string;
  subjectKey: string;
  subjectKeyVersion: number;
  day: string;
  thresholdCode: BreachThresholdCode;
  status: BreachStatus;
  observedValue: bigint;
  thresholdValue: bigint;
}

export interface MarginThresholdConfig {
  minimumMarginBps: bigint;
  maximumDailyCogsMicroUsd: bigint;
  maximumAbsoluteLossMicroUsd: bigint;
}

const globalBreaches = globalThis as typeof globalThis & {
  __vmUnitEconomicsBreaches?: Map<string, ThresholdBreach>;
};

function breaches(): Map<string, ThresholdBreach> {
  if (!globalBreaches.__vmUnitEconomicsBreaches) {
    globalBreaches.__vmUnitEconomicsBreaches = new Map();
  }
  return globalBreaches.__vmUnitEconomicsBreaches;
}

function envBigInt(name: string, fallback: bigint): bigint {
  const value = process.env[name]?.trim();
  if (!value) return fallback;
  if (!/^-?[0-9]+$/.test(value)) throw new Error(`${name} must be an integer.`);
  return BigInt(value);
}

export function getMarginThresholdConfig(): MarginThresholdConfig {
  const minimumMarginBps = envBigInt(
    "VOICEMEMORY_UNIT_ECONOMICS_MIN_MARGIN_BPS",
    2_000n,
  );
  const maximumDailyCogsMicroUsd = envBigInt(
    "VOICEMEMORY_UNIT_ECONOMICS_MAX_DAILY_COGS_MICRO_USD",
    5_000_000n,
  );
  const maximumAbsoluteLossMicroUsd = envBigInt(
    "VOICEMEMORY_UNIT_ECONOMICS_MAX_ABSOLUTE_LOSS_MICRO_USD",
    1_000_000n,
  );
  if (minimumMarginBps < -100_000n || minimumMarginBps > 10_000n) {
    throw new Error("Unit economics minimum margin bps is out of range.");
  }
  if (maximumDailyCogsMicroUsd < 0n) {
    throw new Error("Unit economics maximum daily COGS cannot be negative.");
  }
  if (maximumAbsoluteLossMicroUsd < 0n) {
    throw new Error("Unit economics maximum absolute loss cannot be negative.");
  }
  return { minimumMarginBps, maximumDailyCogsMicroUsd, maximumAbsoluteLossMicroUsd };
}

export async function appendThresholdBreach(row: ThresholdBreach): Promise<boolean> {
  if (!shouldUsePostgresStorage()) {
    if ([...breaches().values()].some((item) => item.dedupKey === row.dedupKey)) return false;
    breaches().set(row.breachKey, { ...row });
    return true;
  }
  const result = await dbQuery(
    `INSERT INTO ue_threshold_breaches
     (breach_key, dedup_key, subject_key, subject_key_version, day, threshold_code,
      status, observed_value, threshold_value)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     ON CONFLICT (dedup_key) DO NOTHING`,
    [
      row.breachKey, row.dedupKey, row.subjectKey, row.subjectKeyVersion, row.day,
      row.thresholdCode, row.status, row.observedValue.toString(), row.thresholdValue.toString(),
    ],
  );
  return (result.rowCount ?? 0) > 0;
}

export function breachesForRollup(
  rollup: DailySubjectRollup,
  config: MarginThresholdConfig = getMarginThresholdConfig(),
): ThresholdBreach[] {
  const candidates: Array<{
    code: BreachThresholdCode;
    observed: bigint;
    threshold: bigint;
  }> = [];
  if (rollup.contributionMarginMicroUsd < 0n) {
    candidates.push({ code: "negative_margin", observed: rollup.contributionMarginMicroUsd, threshold: 0n });
  }
  if (rollup.marginBps !== null && BigInt(rollup.marginBps) < config.minimumMarginBps) {
    candidates.push({
      code: "low_margin_bps",
      observed: BigInt(rollup.marginBps),
      threshold: config.minimumMarginBps,
    });
  }
  if (rollup.totalCogsMicroUsd > config.maximumDailyCogsMicroUsd) {
    candidates.push({
      code: "high_daily_cogs",
      observed: rollup.totalCogsMicroUsd,
      threshold: config.maximumDailyCogsMicroUsd,
    });
  }
  if (rollup.contributionMarginMicroUsd < -config.maximumAbsoluteLossMicroUsd) {
    candidates.push({
      code: "absolute_loss",
      observed: -rollup.contributionMarginMicroUsd,
      threshold: config.maximumAbsoluteLossMicroUsd,
    });
  }
  return candidates.map(({ code, observed, threshold }) => ({
    breachKey: createEconomicsBreachKey(rollup.subjectKey, rollup.day, code, "open"),
    dedupKey: createEconomicsBreachDedupKey(rollup.subjectKey, rollup.day, code, "open"),
    subjectKey: rollup.subjectKey,
    subjectKeyVersion: rollup.subjectKeyVersion,
    day: rollup.day,
    thresholdCode: code,
    status: "open",
    observedValue: observed,
    thresholdValue: threshold,
  }));
}

export async function recordRollupBreaches(
  rollup: DailySubjectRollup,
  config?: MarginThresholdConfig,
): Promise<number> {
  let inserted = 0;
  for (const breach of breachesForRollup(rollup, config)) {
    if (await appendThresholdBreach(breach)) inserted += 1;
  }
  return inserted;
}

export async function summarizeThresholdBreaches(
  fromDay: string,
  toDay: string,
  subjectKey?: string,
): Promise<{
  total: number;
  negativeMargin: boolean;
  lowMarginBps: boolean;
  highDailyCogs: boolean;
  absoluteLoss: boolean;
}> {
  let codes: BreachThresholdCode[];
  if (!shouldUsePostgresStorage()) {
    codes = [...breaches().values()]
      .filter((row) => row.day >= fromDay && row.day <= toDay &&
        (!subjectKey || row.subjectKey === subjectKey))
      .map((row) => row.thresholdCode);
  } else {
    const result = await dbQuery<{ threshold_code: BreachThresholdCode }>(
      `SELECT threshold_code FROM ue_threshold_breaches
       WHERE day >= $1 AND day <= $2
         AND ($3::text IS NULL OR subject_key = $3)
       LIMIT 10000`,
      [fromDay, toDay, subjectKey ?? null],
    );
    codes = result.rows.map((row) => row.threshold_code);
  }
  return {
    total: codes.length,
    negativeMargin: codes.includes("negative_margin"),
    lowMarginBps: codes.includes("low_margin_bps"),
    highDailyCogs: codes.includes("high_daily_cogs"),
    absoluteLoss: codes.includes("absolute_loss"),
  };
}

export function resetUnitEconomicsBreachMemoryForTests(): void {
  breaches().clear();
}
