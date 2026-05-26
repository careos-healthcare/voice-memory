import { readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import {
  getResurfacingFatigueRecords,
  shouldSuppressResurfacingNote,
} from "@/lib/resurfacing/resurfacing-fatigue";
import { buildReadVsSpeakRisk } from "@/lib/reflex/read-vs-speak";
import { getMemoryEligibleEntries } from "@/lib/storage";

const RECENT_SHOWN_WINDOW_MS = 6 * 60 * 60 * 1000;
const MAX_RECENT_SHOWN = 4;

function recentCallbackShownCount(): number {
  const cutoff = Date.now() - RECENT_SHOWN_WINDOW_MS;
  return readLocalEvents().filter(
    (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.shown &&
      new Date(e.at).getTime() >= cutoff,
  ).length;
}

function stackedPromptRisk(): boolean {
  if (typeof window === "undefined") return false;
  const surfaces = Number(sessionStorage.getItem("voicememory_surfaces_before_recording") ?? "0");
  return surfaces >= 2;
}

/** Prefer fewer, sharper interrupts — not feed consumption. */
export function shouldSuppressResurfacingForReflex(noteId?: string): boolean {
  if (noteId && shouldSuppressResurfacingNote(noteId)) return true;

  const fatigue = getResurfacingFatigueRecords();
  const ignoredHeavy = fatigue.filter(
    (row) => row.ignoredCount >= 2 || row.openedWithoutReflection >= 2,
  ).length;
  if (ignoredHeavy >= 2) return true;

  if (recentCallbackShownCount() >= MAX_RECENT_SHOWN) return true;

  const readRisk = buildReadVsSpeakRisk();
  if (readRisk.consumableContinuityRisk || readRisk.passiveReadingLikely) return true;

  if (stackedPromptRisk()) return true;

  return false;
}

export function shouldDelayHomepageContinuityStack(): boolean {
  return shouldSuppressResurfacingForReflex() || buildReadVsSpeakRisk().passiveReadingLikely;
}

export function reflexEmotionalWallpaperRisk(): boolean {
  const entries = getMemoryEligibleEntries();
  if (entries.length < 3) return false;
  const shown = recentCallbackShownCount();
  const readRisk = buildReadVsSpeakRisk();
  return shown >= 3 && (readRisk.passiveReadingLikely || readRisk.repeatedReopenWithoutRecord >= 2);
}
