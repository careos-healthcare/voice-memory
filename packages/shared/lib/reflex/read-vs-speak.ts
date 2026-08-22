import { readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { ONBOARDING_CLARITY_EVENTS } from "@/lib/onboarding/onboarding-observation";
import { readSurfacesBeforeRecording } from "@/lib/reflection/reflection-friction-report";
import type { ReadVsSpeakMetrics, ReadVsSpeakReport } from "@/types/reflex";

const READ_START_KEY = "voicememory_read_vs_speak_start";
const SCROLL_KEY = "voicememory_scroll_before_record";
const REOPEN_KEY = "voicememory_reopen_without_record";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function markHomepageReadingStart(): void {
  if (!isBrowser()) return;
  if (!sessionStorage.getItem(READ_START_KEY)) {
    sessionStorage.setItem(READ_START_KEY, String(Date.now()));
  }
}

export function markScrollBeforeRecorder(): void {
  if (!isBrowser()) return;
  const count = Number(sessionStorage.getItem(SCROLL_KEY) ?? "0") + 1;
  sessionStorage.setItem(SCROLL_KEY, String(count));
}

export function markRecorderEngaged(): void {
  if (!isBrowser()) return;
  const start = Number(sessionStorage.getItem(READ_START_KEY) ?? "0");
  if (start <= 0) return;
  const seconds = Math.round((Date.now() - start) / 1000);
  sessionStorage.setItem("voicememory_last_read_before_record_sec", String(seconds));
  sessionStorage.removeItem(READ_START_KEY);
}

export function recordReopenWithoutRecording(): void {
  if (!isBrowser()) return;
  const count = Number(sessionStorage.getItem(REOPEN_KEY) ?? "0") + 1;
  sessionStorage.setItem(REOPEN_KEY, String(count));
}

function avgReadSeconds(): number | null {
  if (!isBrowser()) return null;
  const raw = sessionStorage.getItem("voicememory_last_read_before_record_sec");
  if (!raw) return null;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 && n < 600 ? n : null;
}

export function buildReadVsSpeakRisk(): ReadVsSpeakMetrics {
  const events = readLocalEvents();
  const callbackOpens = events.filter(
    (e) => e.name === CALLBACK_LEARNING_EVENTS.opened,
  ).length;
  const reflectionsAfter = events.filter(
    (e) => e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter,
  ).length;
  const callbackOpensWithoutRecord = Math.max(0, callbackOpens - reflectionsAfter);

  const repeatedReopen = Number(sessionStorage.getItem(REOPEN_KEY) ?? "0");
  const scrollSignals = Number(sessionStorage.getItem(SCROLL_KEY) ?? "0");
  const avgSeconds = avgReadSeconds();
  const surfaces = readSurfacesBeforeRecording();

  const abandoned = events.filter(
    (e) => e.name === ONBOARDING_CLARITY_EVENTS.recorderAbandoned,
  ).length;

  const consumableContinuityRisk =
    (avgSeconds !== null && avgSeconds > 45) ||
    scrollSignals >= 2 ||
    surfaces >= 3 ||
    callbackOpensWithoutRecord >= 2;

  const passiveReadingLikely =
    consumableContinuityRisk &&
    (repeatedReopen >= 2 || (avgSeconds !== null && avgSeconds > 90));

  return {
    avgSecondsBeforeRecord: avgSeconds,
    callbackOpensWithoutRecord,
    repeatedReopenWithoutRecord: repeatedReopen,
    scrollBeforeRecordSignals: scrollSignals,
    consumableContinuityRisk,
    passiveReadingLikely,
  };
}

export function buildReadVsSpeakReport(): ReadVsSpeakReport {
  const metrics = buildReadVsSpeakRisk();
  const warnings: ReadVsSpeakReport["warnings"] = [];

  if (metrics.consumableContinuityRisk) {
    warnings.push({
      id: "consumable_continuity",
      message: "Continuity may be consumable — reading before speaking is elevated.",
    });
  }
  if (metrics.passiveReadingLikely) {
    warnings.push({
      id: "passive_reading",
      message: "Passive reading behavior detected — mic centrality at risk.",
    });
  }
  if (metrics.callbackOpensWithoutRecord >= 2) {
    warnings.push({
      id: "callback_no_mic",
      message: "Callbacks open without recording — emotional browsing pattern.",
    });
  }

  return { metrics, warnings };
}
