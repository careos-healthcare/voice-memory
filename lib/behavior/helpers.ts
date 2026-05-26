import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { InsightConfidence } from "@/types/behavior-truth";

export function ratePercent(numerator: number, denominator: number): number {
  if (denominator <= 0) return 0;
  return Math.round((numerator / denominator) * 100);
}

export function sampleConfidence(count: number): InsightConfidence {
  if (count >= 12) return "high";
  if (count >= 4) return "moderate";
  return "low";
}

export function hoursBetween(earlierIso: string, laterIso: string): number {
  const delta = new Date(laterIso).getTime() - new Date(earlierIso).getTime();
  if (!Number.isFinite(delta) || delta < 0) return 0;
  return delta / (60 * 60 * 1000);
}

export function medianHours(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return Math.round(((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2);
  }
  return Math.round(sorted[mid] ?? 0);
}

export function countEvents(events: LocalAnalyticsEvent[], name: string): number {
  return events.filter((event) => event.name === name).length;
}

export function eventsNamed(
  events: LocalAnalyticsEvent[],
  names: Set<string> | string[],
): LocalAnalyticsEvent[] {
  const set = names instanceof Set ? names : new Set(names);
  return events.filter((event) => set.has(event.name));
}

export function firstEventAt(events: LocalAnalyticsEvent[], name: string): string | null {
  const match = events.find((event) => event.name === name);
  return match?.at ?? null;
}

export function formatSampleNote(numerator: number, denominator: number): string {
  return `${numerator} of ${denominator} on this device`;
}

export function qualifyInterpretation(
  text: string,
  confidence: InsightConfidence,
): string {
  if (confidence === "low") {
    return `${text} (too few events on this device to be sure yet.)`;
  }
  if (confidence === "moderate") {
    return `${text} (early signal on this device — treat as tentative.)`;
  }
  return text;
}
