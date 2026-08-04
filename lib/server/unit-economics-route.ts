import { unitEconomicsMaxReconciliationDays } from "@/lib/server/unit-economics-config";

const DAY = /^\d{4}-\d{2}-\d{2}$/;
export const ECONOMICS_SUBJECT_KEY = /^ue:v[1-9][0-9]*:[A-Za-z0-9_-]{43}$/;

function parseDay(value: unknown): string | null {
  if (typeof value !== "string" || !DAY.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value
    ? null
    : value;
}

export function yesterdayUtc(): string {
  return new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
}

export function boundedEconomicsDateRange(
  fromValue: unknown,
  toValue: unknown,
  defaults: { from: string; to: string },
): { ok: true; from: string; to: string } | { ok: false; code: string } {
  const from = fromValue === undefined ? defaults.from : parseDay(fromValue);
  const to = toValue === undefined ? defaults.to : parseDay(toValue);
  if (!from || !to || from > to) return { ok: false, code: "INVALID_DATE_RANGE" };
  const inclusiveDays =
    Math.floor((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1;
  if (inclusiveDays > unitEconomicsMaxReconciliationDays()) {
    return { ok: false, code: "DATE_RANGE_TOO_LARGE" };
  }
  return { ok: true, from, to };
}
