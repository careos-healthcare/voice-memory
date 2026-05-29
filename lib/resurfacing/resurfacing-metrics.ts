import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const METRICS_KEY = "voicememory_resurfacing_qa_metrics";

export type ResurfacingMetricName =
  | "callback_shown"
  | "callback_dismissed"
  | "callback_fit_clicked"
  | "not_me_clicked"
  | "wrong_topic_clicked"
  | "wrong_person_clicked"
  | "too_intense_clicked"
  | "too_vague_clicked"
  | "already_know_clicked"
  | "show_less_like_this_clicked"
  | "related_memory_opened"
  | "voice_replayed_after_callback"
  | "rerecord_within_10min"
  | "return_next_day_after_callback"
  | "callback_suppressed_no_evidence"
  | "callback_suppressed_stale"
  | "callback_suppressed_feedback"
  | "callback_suppressed_ambiguity"
  | "low_confidence_suppressed"
  | "generic_phrase_shown"
  | "quote_backed_shown";

export interface ResurfacingQaMetrics {
  callback_shown: number;
  callback_dismissed: number;
  callback_fit_clicked: number;
  not_me_clicked: number;
  wrong_topic_clicked: number;
  wrong_person_clicked: number;
  too_intense_clicked: number;
  too_vague_clicked: number;
  already_know_clicked: number;
  show_less_like_this_clicked: number;
  related_memory_opened: number;
  voice_replayed_after_callback: number;
  rerecord_within_10min: number;
  return_next_day_after_callback: number;
  callback_suppressed_no_evidence: number;
  callback_suppressed_stale: number;
  callback_suppressed_feedback: number;
  callback_suppressed_ambiguity: number;
  low_confidence_suppressed: number;
  generic_phrase_shown: number;
  quote_backed_shown: number;
  lastShownAt: string | null;
  lastConfidence: number | null;
  updatedAt: string;
}

const EMPTY: ResurfacingQaMetrics = {
  callback_shown: 0,
  callback_dismissed: 0,
  callback_fit_clicked: 0,
  not_me_clicked: 0,
  wrong_topic_clicked: 0,
  wrong_person_clicked: 0,
  too_intense_clicked: 0,
  too_vague_clicked: 0,
  already_know_clicked: 0,
  show_less_like_this_clicked: 0,
  related_memory_opened: 0,
  voice_replayed_after_callback: 0,
  rerecord_within_10min: 0,
  return_next_day_after_callback: 0,
  callback_suppressed_no_evidence: 0,
  callback_suppressed_stale: 0,
  callback_suppressed_feedback: 0,
  callback_suppressed_ambiguity: 0,
  low_confidence_suppressed: 0,
  generic_phrase_shown: 0,
  quote_backed_shown: 0,
  lastShownAt: null,
  lastConfidence: null,
  updatedAt: new Date(0).toISOString(),
};

function isBrowser(): boolean {
  return typeof localStorage !== "undefined";
}

function read(): ResurfacingQaMetrics {
  if (!isBrowser()) return { ...EMPTY };
  try {
    const raw = localStorage.getItem(METRICS_KEY);
    if (!raw) return { ...EMPTY };
    const parsed = JSON.parse(raw) as Partial<ResurfacingQaMetrics>;
    return { ...EMPTY, ...parsed };
  } catch {
    return { ...EMPTY };
  }
}

function write(metrics: ResurfacingQaMetrics): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(
    METRICS_KEY,
    JSON.stringify({ ...metrics, updatedAt: new Date().toISOString() }),
  );
}

export function getResurfacingQaMetrics(): ResurfacingQaMetrics {
  return read();
}

/** Metrics payload — phraseKey only, never raw journal text. */
export function recordResurfacingMetric(
  name: ResurfacingMetricName,
  extra?: { confidence?: number; phraseKey?: string },
): void {
  const m = read();
  const key = name as keyof ResurfacingQaMetrics;
  if (typeof m[key] === "number") {
    (m[key] as number) += 1;
  }
  if (name === "callback_shown") {
    m.lastShownAt = new Date().toISOString();
    if (typeof extra?.confidence === "number") {
      m.lastConfidence = extra.confidence;
    }
  }
  write(m);

  if (typeof fetch !== "undefined") {
    void fetch("/api/metrics/resurfacing", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({
        event: name,
        confidence: extra?.confidence,
        phraseKey: extra?.phraseKey,
      }),
    }).catch(() => {
      /* local-first — server metrics optional */
    });
  }
}

export function syncRerecordMetricFromFirstReturn(): void {
  void import("@/lib/continuity/first-return-observation").then((mod) => {
    const fr = mod.getFirstReturnMetrics();
    if (fr.rerecordWithin10MinAt) {
      const m = read();
      if (m.rerecord_within_10min === 0) {
        m.rerecord_within_10min = 1;
        write(m);
      }
    }
  });
}
