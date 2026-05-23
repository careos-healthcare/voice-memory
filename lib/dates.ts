/** Calendar day key in local timezone (YYYY-MM-DD). */
export function toDayKey(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function todayKey(): string {
  return toDayKey(new Date());
}

export function addDaysToKey(dayKey: string, delta: number): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + delta);
  return toDayKey(date);
}

export function daysBetweenKeys(from: string, to: string): number {
  const [y1, m1, d1] = from.split("-").map(Number);
  const [y2, m2, d2] = to.split("-").map(Number);
  const a = new Date(y1, m1 - 1, d1).getTime();
  const b = new Date(y2, m2 - 1, d2).getTime();
  return Math.round((b - a) / (1000 * 60 * 60 * 24));
}

export function startOfWeekKey(reference: string = todayKey()): string {
  const [y, m, d] = reference.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  const dow = date.getDay();
  const mondayOffset = dow === 0 ? -6 : 1 - dow;
  date.setDate(date.getDate() + mondayOffset);
  return toDayKey(date);
}
