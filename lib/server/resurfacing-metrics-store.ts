import { createHash } from "node:crypto";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { ResurfacingMetricName } from "@/lib/resurfacing/resurfacing-metrics";

export interface ResurfacingEventInput {
  subjectKey: string;
  userId?: string;
  eventName: ResurfacingMetricName;
  confidence?: number;
  phraseKey?: string;
}

export interface ResurfacingMetricsAggregate {
  callback_shown: number;
  callback_dismissed: number;
  not_me_clicked: number;
  rerecord_within_10min: number;
  low_confidence_suppressed: number;
  generic_phrase_shown: number;
  quote_backed_shown: number;
  generic_phrase_rate: number;
  quote_backed_rate: number;
  repeated_callback_rate: number;
}

const memoryEvents = globalThis as typeof globalThis & {
  __vmResurfacingEvents?: ResurfacingEventInput[];
};

function confidenceBucket(confidence?: number): string | null {
  if (typeof confidence !== "number" || !Number.isFinite(confidence)) return null;
  if (confidence < 50) return "0-49";
  if (confidence < 68) return "50-67";
  if (confidence < 80) return "68-79";
  return "80+";
}

function phraseHash(phraseKey?: string): string | null {
  if (!phraseKey?.trim()) return null;
  return createHash("sha256").update(phraseKey.trim()).digest("hex").slice(0, 24);
}

export async function recordResurfacingEvent(
  input: ResurfacingEventInput,
): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO resurfacing_events (user_id, subject_key, event_name, confidence_bucket, phrase_key_hash, metadata)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        input.userId ?? null,
        input.subjectKey,
        input.eventName,
        confidenceBucket(input.confidence),
        phraseHash(input.phraseKey),
        JSON.stringify({ confidence: input.confidence ?? null }),
      ],
    );
    return;
  }
  if (!memoryEvents.__vmResurfacingEvents) memoryEvents.__vmResurfacingEvents = [];
  memoryEvents.__vmResurfacingEvents.push(input);
}

const COUNT_KEYS: Array<keyof ResurfacingMetricsAggregate> = [
  "callback_shown",
  "callback_dismissed",
  "not_me_clicked",
  "rerecord_within_10min",
  "low_confidence_suppressed",
  "generic_phrase_shown",
  "quote_backed_shown",
];

function applyMetricCount(
  agg: ResurfacingMetricsAggregate,
  eventName: string,
  delta: number,
  increment = false,
): void {
  if (!COUNT_KEYS.includes(eventName as keyof ResurfacingMetricsAggregate)) return;
  const key = eventName as (typeof COUNT_KEYS)[number];
  if (increment) {
    agg[key] += delta;
  } else {
    agg[key] = delta;
  }
}

export async function aggregateResurfacingMetrics(
  subjectKey?: string,
): Promise<ResurfacingMetricsAggregate> {
  const empty: ResurfacingMetricsAggregate = {
    callback_shown: 0,
    callback_dismissed: 0,
    not_me_clicked: 0,
    rerecord_within_10min: 0,
    low_confidence_suppressed: 0,
    generic_phrase_shown: 0,
    quote_backed_shown: 0,
    generic_phrase_rate: 0,
    quote_backed_rate: 0,
    repeated_callback_rate: 0,
  };

  if (shouldUsePostgresStorage()) {
    const where = subjectKey ? "WHERE subject_key = $1" : "";
    const params = subjectKey ? [subjectKey] : [];
    const result = await dbQuery<{ event_name: string; count: string }>(
      `SELECT event_name, COUNT(*)::text AS count
       FROM resurfacing_events
       ${where}
       GROUP BY event_name`,
      params,
    );
    for (const row of result.rows) {
      applyMetricCount(empty, row.event_name, Number(row.count));
    }
  } else {
    const events = memoryEvents.__vmResurfacingEvents ?? [];
    const filtered = subjectKey
      ? events.filter((e) => e.subjectKey === subjectKey)
      : events;
    for (const e of filtered) {
      applyMetricCount(empty, e.eventName, 1, true);
    }
  }

  const shown = empty.callback_shown || 0;
  if (shown > 0) {
    empty.generic_phrase_rate = empty.generic_phrase_shown / shown;
    empty.quote_backed_rate = empty.quote_backed_shown / shown;
    empty.repeated_callback_rate = empty.callback_dismissed / shown;
  }
  return empty;
}
