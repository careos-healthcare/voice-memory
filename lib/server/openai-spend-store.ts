import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { MicroUsd } from "@/lib/server/openai-cost-estimator";

function dayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

const globalSpend = globalThis as typeof globalThis & {
  __vmOpenAiSpendDay?: Map<string, number>;
};

function memorySpendMap(): Map<string, number> {
  if (!globalSpend.__vmOpenAiSpendDay) {
    globalSpend.__vmOpenAiSpendDay = new Map();
  }
  return globalSpend.__vmOpenAiSpendDay;
}

function memoryKey(subject: string, day: string): string {
  return `${subject}:${day}`;
}

async function readSpendPostgres(subject: string, day: string): Promise<number> {
  const result = await dbQuery<{ spend_micro_usd: string | number }>(
    `SELECT spend_micro_usd FROM openai_daily_spend
     WHERE subject_key = $1 AND day_key = $2`,
    [subject, day],
  );
  const raw = result.rows[0]?.spend_micro_usd;
  if (raw === undefined || raw === null) return 0;
  return Number(raw);
}

async function reserveSpendPostgres(
  subject: string,
  day: string,
  deltaMicro: MicroUsd,
  limitMicro: MicroUsd,
): Promise<{ ok: boolean; spent: number }> {
  const result = await dbQuery<{ spend_micro_usd: string | number }>(
    `INSERT INTO openai_daily_spend (subject_key, day_key, spend_micro_usd)
     VALUES ($1, $2, $3)
     ON CONFLICT (subject_key, day_key)
     DO UPDATE SET spend_micro_usd = openai_daily_spend.spend_micro_usd + $3
     WHERE openai_daily_spend.spend_micro_usd + $3 <= $4
     RETURNING spend_micro_usd`,
    [subject, day, deltaMicro, limitMicro],
  );
  if (result.rows.length === 0) {
    const spent = await readSpendPostgres(subject, day);
    return { ok: false, spent };
  }
  return { ok: true, spent: Number(result.rows[0].spend_micro_usd) };
}

function reserveSpendMemory(
  subject: string,
  day: string,
  deltaMicro: MicroUsd,
  limitMicro: MicroUsd,
): { ok: boolean; spent: number } {
  const map = memorySpendMap();
  const key = memoryKey(subject, day);
  const current = map.get(key) ?? 0;
  if (current + deltaMicro > limitMicro) {
    return { ok: false, spent: current };
  }
  const next = current + deltaMicro;
  map.set(key, next);
  return { ok: true, spent: next };
}

export async function reserveOpenAiSpend(
  subject: string,
  deltaMicro: MicroUsd,
  limitMicro: MicroUsd,
  day: string = dayKey(),
): Promise<{ ok: boolean; spent: number; limit: number }> {
  if (limitMicro <= 0) {
    return { ok: false, spent: await peekOpenAiSpend(subject, day), limit: limitMicro };
  }
  if (deltaMicro <= 0) {
    return { ok: true, spent: await peekOpenAiSpend(subject, day), limit: limitMicro };
  }
  if (deltaMicro > limitMicro) {
    return {
      ok: false,
      spent: await peekOpenAiSpend(subject, day),
      limit: limitMicro,
    };
  }

  const result = shouldUsePostgresStorage()
    ? await reserveSpendPostgres(subject, day, deltaMicro, limitMicro)
    : reserveSpendMemory(subject, day, deltaMicro, limitMicro);

  return { ...result, limit: limitMicro };
}

export async function peekOpenAiSpend(
  subject: string,
  day: string = dayKey(),
): Promise<number> {
  if (shouldUsePostgresStorage()) {
    return readSpendPostgres(subject, day);
  }
  return memorySpendMap().get(memoryKey(subject, day)) ?? 0;
}

export function usesDurableOpenAiSpend(): boolean {
  return shouldUsePostgresStorage();
}

/** Production must not use memory-only spend tracking. */
export function assertProductionOpenAiSpendIsDurable(): void {
  if (process.env.NODE_ENV !== "production") return;
  if (!usesDurableOpenAiSpend()) {
    throw new Error(
      "Production requires DATABASE_URL for DB-backed OpenAI spend limits.",
    );
  }
}
