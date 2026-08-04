import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

export type ApiUsageKind =
  | "transcribe"
  | "analyze"
  | "atmosphere"
  | "attest";

const DAILY_LIMIT_ENV: Record<ApiUsageKind, string> = {
  transcribe: "VOICEMEMORY_DAILY_TRANSCRIBE_LIMIT",
  analyze: "VOICEMEMORY_DAILY_ANALYZE_LIMIT",
  atmosphere: "VOICEMEMORY_DAILY_ATMOSPHERE_LIMIT",
  attest: "VOICEMEMORY_DAILY_ATTEST_LIMIT",
};

const MINUTE_LIMIT_ENV: Record<ApiUsageKind, string> = {
  transcribe: "VOICEMEMORY_MINUTE_TRANSCRIBE_LIMIT",
  analyze: "VOICEMEMORY_MINUTE_ANALYZE_LIMIT",
  atmosphere: "VOICEMEMORY_MINUTE_ATMOSPHERE_LIMIT",
  attest: "VOICEMEMORY_MINUTE_ATTEST_LIMIT",
};

const DEVELOPMENT_DAILY_LIMITS: Record<ApiUsageKind, number> = {
  transcribe: 40, analyze: 40, atmosphere: 20, attest: 60,
};
const DEVELOPMENT_MINUTE_LIMITS: Record<ApiUsageKind, number> = {
  transcribe: 6, analyze: 10, atmosphere: 4, attest: 12,
};

function configuredLimit(
  kind: ApiUsageKind,
  envNames: Record<ApiUsageKind, string>,
  development: Record<ApiUsageKind, number>,
): number {
  const raw = process.env[envNames[kind]]?.trim();
  if (!raw) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(`USAGE_RATE_LIMIT_CONFIG_INVALID:${envNames[kind]}`);
    }
    return development[kind];
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`USAGE_RATE_LIMIT_CONFIG_INVALID:${envNames[kind]}`);
  }
  return value;
}

function dailyLimit(kind: ApiUsageKind): number {
  return configuredLimit(kind, DAILY_LIMIT_ENV, DEVELOPMENT_DAILY_LIMITS);
}

function minuteLimit(kind: ApiUsageKind): number {
  return configuredLimit(kind, MINUTE_LIMIT_ENV, DEVELOPMENT_MINUTE_LIMITS);
}

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
  const limit = minuteLimit(kind);
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
  if (current >= minuteLimit(kind)) return false;
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
  const limit = dailyLimit(kind);
  if (current >= limit) {
    return {
      allowed: false,
      reason: "daily_cap",
      dailyCount: current,
      dailyLimit: limit,
    };
  }

  const after = shouldUsePostgresStorage()
    ? await incrementDayPostgres(subject, day, kind)
    : incrementDayMemory(subject, day, kind);

  return {
    allowed: true,
    dailyCount: after[kind],
    dailyLimit: limit,
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

export async function deleteApiUsageForSubject(subject: string): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const [daily, minute] = await Promise.all([
      dbQuery(`DELETE FROM api_usage WHERE subject_key = $1`, [subject]),
      dbQuery(`DELETE FROM api_minute_usage WHERE subject_key = $1`, [subject]),
    ]);
    return (daily.rowCount ?? 0) + (minute.rowCount ?? 0);
  }
  let removed = 0;
  for (const map of [dayMap(), minuteMap()]) {
    for (const key of map.keys()) {
      if (key.startsWith(`${subject}:`)) {
        map.delete(key);
        removed += 1;
      }
    }
  }
  return removed;
}

export function localApiUsageExists(subject: string): boolean {
  return [...dayMap().keys(), ...minuteMap().keys()].some((key) =>
    key.startsWith(`${subject}:`),
  );
}

export function getDailyLimits(): Record<ApiUsageKind, number> {
  return {
    transcribe: dailyLimit("transcribe"),
    analyze: dailyLimit("analyze"),
    atmosphere: dailyLimit("atmosphere"),
    attest: dailyLimit("attest"),
  };
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
