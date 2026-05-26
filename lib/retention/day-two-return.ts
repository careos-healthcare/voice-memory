import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildRepeatedThemeReport } from "@/lib/patterns/repeated-themes";
import { rankByConcreteEvidence } from "@/lib/resurfacing/evidence-engine";
import {
  collectResurfacingConfidenceCandidates,
  enrichNoteWithResurfacingConfidence,
} from "@/lib/revisit/resurfacing-confidence";
import { pickBestCallback, rankCallbacksByTuning } from "@/lib/refinement/callback-tuning";
import { observeSessionDay2Return } from "@/lib/retention/session-retention";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const DAY_TWO_ANCHOR_KEY = "voicememory_first_reflection_at";
const DAY_TWO_PROMPT_KEY = "voicememory_day_two_prompt_at";

export const DAY_TWO_FALLBACK_PROMPT =
  "Record again if this comes back today.";

export interface DayTwoReturnOffer {
  id: "day_two_callback" | "day_two_fallback";
  text: string;
  note: MemoryNote | null;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readFirstReflectionAt(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(DAY_TWO_ANCHOR_KEY);
}

export function anchorFirstReflectionForDayTwo(createdAt: string): void {
  if (!isBrowser()) return;
  if (localStorage.getItem(DAY_TWO_ANCHOR_KEY)) return;
  localStorage.setItem(DAY_TWO_ANCHOR_KEY, createdAt);
}

function alreadyShownToday(): boolean {
  if (!isBrowser()) return true;
  const shown = localStorage.getItem(DAY_TWO_PROMPT_KEY);
  if (!shown) return false;
  return toDayKey(shown) === toDayKey(new Date().toISOString());
}

function markShownToday(): void {
  if (!isBrowser()) return;
  localStorage.setItem(DAY_TWO_PROMPT_KEY, new Date().toISOString());
}

function isCalendarDayTwo(firstReflectionAt: string, now = new Date()): boolean {
  const gap = daysBetweenKeys(toDayKey(firstReflectionAt), toDayKey(now.toISOString()));
  return gap === 1;
}

function pickDayTwoCallback(entries: JournalEntry[]): MemoryNote | null {
  const candidates = collectResurfacingConfidenceCandidates(entries);
  const ranked = rankCallbacksByTuning(
    rankByConcreteEvidence(candidates, entries).map((row) => row.note),
    entries,
  ).map((row) => row.note);
  const best = pickBestCallback(ranked, entries, 44);
  return best ? enrichNoteWithResurfacingConfidence(best, entries) : null;
}

/** Calm day-2 return prompt after first reflection — evidence-backed or fallback. */
export function pickDayTwoReturnOffer(entries: JournalEntry[]): DayTwoReturnOffer | null {
  if (!isBrowser()) return null;
  const firstAt = readFirstReflectionAt();
  if (!firstAt || !isCalendarDayTwo(firstAt)) return null;
  if (alreadyShownToday()) return null;

  const themes = buildRepeatedThemeReport(entries);
  const hasThemeEvidence =
    themes.phrases.length > 0 ||
    themes.concerns.length > 0 ||
    themes.entities.length > 0;

  const callback = hasThemeEvidence ? pickDayTwoCallback(entries) : null;

  markShownToday();
  observeSessionDay2Return({ hasCallback: callback ? "1" : "0" });

  if (callback?.text) {
    return {
      id: "day_two_callback",
      text: callback.text,
      note: callback,
    };
  }

  return {
    id: "day_two_fallback",
    text: DAY_TWO_FALLBACK_PROMPT,
    note: null,
  };
}
