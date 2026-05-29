import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

export type ApiUsageKind =
  | "transcribe"
  | "analyze"
  | "atmosphere"
  | "attest";

const DAILY_LIMITS: Record<ApiUsageKind, number> = {
  transcribe: Number(process.env.VOICEMEMORY_DAILY_TRANSCRIBE_LIMIT ?? "40"),
  analyze: Number(process.env.VOICEMEMORY_DAILY_ANALYZE_LIMIT ?? "40"),
  atmosphere: Number(process.env.VOICEMEMORY_DAILY_ATMOSPHERE_LIMIT ?? "20"),
  attest: Number(process.env.VOICEMEMORY_DAILY_ATTEST_LIMIT ?? "60"),
};

const MINUTE_BURST: Record<ApiUsageKind, number> = {
  transcribe: Number(process.env.VOICEMEMORY_MINUTE_TRANSCRIBE_LIMIT ?? "6"),
  analyze: Number(process.env.VOICEMEMORY_MINUTE_ANALYZE_LIMIT ?? "10"),
  atmosphere: Number(process.env.VOICEMEMORY_MINUTE_ATMOSPHERE_LIMIT ?? "4"),
  attest: Number(process.env.VOICEMEMORY_MINUTE_ATTEST_LIMIT ?? "12"),
};

const DAY_COLUMN: Record<ApiUsageKind, string> = {
  transcribe: "transcribe_count",
  analyze: "analyze_count",
  atmosphere: "atmosphere_count",
  attest: "attest_count",
};

type DayRow = {
  transcribe: number;
  analyze: number;
  atmosphere: number;
  attest: number;
};

const globalUsage = globalThis as typeof globalThis & {
  __vmApiMinute?: Map<string, number>;
  __vmApiDay?: Map<string, DayRow>;
};

function minuteMap(): Map<string, number> {
  if (!globalUsage.__vmApiMinute) globalUsage.__vmApiMinute = new Map();
  return globalUsage.__vmApiMinute;
}

function dayMap(): Map<string, DayRow> {
  if (!globalUsage.__vmApiDay) globalUsage.__vmApiDay = new Map();
  return globalUsage.__vmApiDay;
}

function dayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function minuteKey(): string {
  const d = new Date();
  return `${d.toISOString().slice(0, 16)}`;
}

function emptyDayRow(): DayRow {
  return { transcribe: 0, analyze: 0, atmosphere: 0, attest: 0 };
}

function rowFromPostgres(row: {
  transcribe_count: number;
  analyze_count: number;
  atmosphere_count?: number;
  attest_count?: number;
}): DayRow {
  return {
    transcribe: row.transcribe_count,
    analyze: row.analyze_count,
    atmosphere: row.atmosphere_count ?? 0,
    attest: row.attest_count ?? 0,
  };
}

async function checkMinuteBurstPostgres(
  subject: string,
  kind: ApiUsageKind,
): Promise<boolean> {
  const key = minuteKey();
  const limit = MINUTE_BURST[kind];
  const result = await dbQuery<{ request_count: number }>(
    `INSERT INTO api_minute_usage (subject_key, endpoint, minute_key, request_count)
     VALUES ($1, $2, $3, 1)
     ON CONFLICT (subject_key, endpoint, minute_key)
     DO UPDATE SET request_count = api_minute_usage.request_count + 1
     RETURNING request_count`,
    [subject, kind, key],
  );
  const count = result.rows[0]?.request_count ?? 1;
  return count <= limit;
}

function checkMinuteBurstMemory(subject: string, kind: ApiUsageKind): boolean {
  const mapKey = `${subject}:${kind}:${minuteKey()}`;
  const map = minuteMap();
  const current = map.get(mapKey) ?? 0;
  if (current >= MINUTE_BURST[kind]) return false;
  map.set(mapKey, current + 1);
  return true;
}

async function readDayPostgres(subject: string, day: string): Promise<DayRow> {
  const result = await dbQuery<{
    transcribe_count: number;
    analyze_count: number;
    atmosphere_count: number;
    attest_count: number;
  }>(
    `SELECT transcribe_count, analyze_count, atmosphere_count, attest_count
     FROM api_usage
     WHERE subject_key = $1 AND day_key = $2`,
    [subject, day],
  );
  const row = result.rows[0];
  if (!row) return emptyDayRow();
  return rowFromPostgres(row);
}

async function incrementDayPostgres(
  subject: string,
  day: string,
  kind: ApiUsageKind,
): Promise<DayRow> {
  const col = DAY_COLUMN[kind];
  await dbQuery(
    `INSERT INTO api_usage (subject_key, day_key, transcribe_count, analyze_count, atmosphere_count, attest_count)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (subject_key, day_key) DO UPDATE SET
       ${col} = api_usage.${col} + 1`,
    [
      subject,
      day,
      kind === "transcribe" ? 1 : 0,
      kind === "analyze" ? 1 : 0,
      kind === "atmosphere" ? 1 : 0,
      kind === "attest" ? 1 : 0,
    ],
  );
  return readDayPostgres(subject, day);
}

function readDayMemory(subject: string, day: string): DayRow {
  const key = `${subject}:${day}`;
  return dayMap().get(key) ?? emptyDayRow();
}

function incrementDayMemory(subject: string, day: string, kind: ApiUsageKind): DayRow {
  const key = `${subject}:${day}`;
  const map = dayMap();
  const row = map.get(key) ?? emptyDayRow();
  row[kind] += 1;
  map.set(key, row);
  return row;
}

export interface UsageCheckResult {
  allowed: boolean;
  reason?: "minute_burst" | "daily_cap";
  dailyCount?: number;
  dailyLimit?: number;
}

export async function checkAndRecordApiUsage(
  subject: string,
  kind: ApiUsageKind,
): Promise<UsageCheckResult> {
  const minuteOk = shouldUsePostgresStorage()
    ? await checkMinuteBurstPostgres(subject, kind)
    : checkMinuteBurstMemory(subject, kind);

  if (!minuteOk) {
    return { allowed: false, reason: "minute_burst" };
  }

  const day = dayKey();
  const before = shouldUsePostgresStorage()
    ? await readDayPostgres(subject, day)
    : readDayMemory(subject, day);

  const current = before[kind];
  if (current >= DAILY_LIMITS[kind]) {
    return {
      allowed: false,
      reason: "daily_cap",
      dailyCount: current,
      dailyLimit: DAILY_LIMITS[kind],
    };
  }

  const after = shouldUsePostgresStorage()
    ? await incrementDayPostgres(subject, day, kind)
    : incrementDayMemory(subject, day, kind);

  return {
    allowed: true,
    dailyCount: after[kind],
    dailyLimit: DAILY_LIMITS[kind],
  };
}

/** For tests — read persisted day counts without incrementing. */
export async function peekDayUsage(
  subject: string,
  day: string = dayKey(),
): Promise<DayRow> {
  return shouldUsePostgresStorage()
    ? readDayPostgres(subject, day)
    : readDayMemory(subject, day);
}

export function getDailyLimits(): typeof DAILY_LIMITS {
  return { ...DAILY_LIMITS };
}

export function usesDurableRateLimits(): boolean {
  return shouldUsePostgresStorage();
}

/** Production must not use memory-only rate limiting. */
export function assertProductionRateLimiterIsDurable(): void {
  if (process.env.NODE_ENV !== "production") return;
  if (!usesDurableRateLimits()) {
    throw new Error(
      "Production requires DATABASE_URL for DB-backed global rate limits.",
    );
  }
}
