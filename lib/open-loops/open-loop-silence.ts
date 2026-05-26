import type { OpenLoop } from "@/types/open-loop";

const LONG_ABSENCE_DAYS = 14;

function daysBetween(isoA: string, isoB: string): number {
  const ms = Math.abs(new Date(isoB).getTime() - new Date(isoA).getTime());
  return Math.round(ms / (1000 * 60 * 60 * 24));
}

/** True when mention history shows a long quiet gap before the latest mention. */
export function hasLongAbsenceReturn(loop: OpenLoop): boolean {
  const history = loop.mentionHistory ?? [];
  if (history.length < 2) return false;

  const sorted = [...history].sort(
    (a, b) => new Date(a).getTime() - new Date(b).getTime(),
  );
  const previous = sorted[sorted.length - 2];
  const latest = sorted[sorted.length - 1];
  return daysBetween(previous, latest) >= LONG_ABSENCE_DAYS;
}

/** Silence-first — do not resurface during long quiet; only when thread returns with evidence. */
export function shouldAllowAbsenceResurfacing(loop: OpenLoop): boolean {
  if (loop.status === "closed") return false;
  return hasLongAbsenceReturn(loop);
}
