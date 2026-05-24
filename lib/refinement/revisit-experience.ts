import { recordCallbackSurfaced } from "@/lib/callback-interaction-signals";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import { trackLocalEvent } from "@/lib/local-analytics";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { entryResurfacingNotes } from "@/lib/memory/resurfacing";
import { entryRevisitationNotes } from "@/lib/memory/revisitation";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { pickBestCallback, rankCallbacksByTuning } from "@/lib/refinement/callback-tuning";
import { entryKnowsMeMoment } from "@/lib/refinement/knows-me-moments";
import {
  markRevisitBoost,
  recordEmotionalNoteShown,
  shouldAllowEmotionalNote,
} from "@/lib/refinement/emotional-timing";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const REVISIT_NAV_KEY = "voicememory_revisit_nav";

export const REVISIT_QUIET_COPY_EXAMPLES = [
  "This may read differently now.",
  "You sound different from here.",
  "This was before it got quieter.",
  "You had not named it yet.",
] as const;

export type RevisitQuietCopy = (typeof REVISIT_QUIET_COPY_EXAMPLES)[number];

export type RevisitSource =
  | "prior_view"
  | "memory_note"
  | "resurfacing"
  | "revisitation"
  | "bookmark"
  | "thread"
  | "timeline"
  | "memory"
  | "monthly";

export interface RevisitContext {
  isRevisit: boolean;
  sources: RevisitSource[];
}

export interface RevisitExperiencePresentation {
  isRevisit: boolean;
  sources: RevisitSource[];
  primaryCallback: MemoryNote | null;
  thenVsNow: MemoryNote | null;
  quietRealization: MemoryNote | null;
  followupPrompt: FollowupPrompt | null;
}

interface RevisitNavigationHint {
  entryId: string;
  source: RevisitSource;
  at: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function isDuplicateNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

function realizationNote(text: string, entryId: string): MemoryNote {
  return {
    id: `revisit-realization-${entryId}`,
    text,
    category: "returned",
    confidence: 64,
    entryId,
  };
}

/** Mark navigation toward an entry as a memory-driven revisit. */
export function markRevisitNavigation(entryId: string, source: RevisitSource): void {
  if (!isBrowser()) return;
  const payload: RevisitNavigationHint = {
    entryId,
    source,
    at: Date.now(),
  };
  sessionStorage.setItem(REVISIT_NAV_KEY, JSON.stringify(payload));
}

/** Read and clear a pending revisit navigation hint for this entry. */
export function consumeRevisitNavigation(entryId: string): RevisitSource | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(REVISIT_NAV_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as RevisitNavigationHint;
    sessionStorage.removeItem(REVISIT_NAV_KEY);
    if (parsed.entryId !== entryId) return null;
    if (Date.now() - parsed.at > 1000 * 60 * 30) return null;
    return parsed.source;
  } catch {
    return null;
  }
}

export function revisitSourceFromNote(note: MemoryNote): RevisitSource {
  if (note.id.startsWith("resurface-")) return "resurfacing";
  if (note.id.startsWith("revisit-")) return "revisitation";
  if (note.id.startsWith("fam-resurface-")) return "memory";
  if (note.id.startsWith("tvn-")) return "memory_note";
  return "memory_note";
}

export function revisitSourceFromPath(pathname: string): RevisitSource | null {
  if (pathname.startsWith("/timeline")) return "timeline";
  if (pathname.startsWith("/memory")) return "memory";
  if (pathname.startsWith("/monthly")) return "monthly";
  if (pathname.startsWith("/threads")) return "thread";
  if (pathname.startsWith("/bookmarks")) return "bookmark";
  return null;
}

/** Detect whether this entry page load is emotionally a revisit. */
export function detectRevisitContext(entryId: string): RevisitContext {
  const sources: RevisitSource[] = [];
  const nav = consumeRevisitNavigation(entryId);
  if (nav) sources.push(nav);
  if (getBookmarkForEntry(entryId)) sources.push("bookmark");
  const summary = entryInteractionSummary(entryId);
  if ((summary?.viewCount ?? 0) > 1) sources.push("prior_view");

  return {
    isRevisit: sources.length > 0,
    sources: [...new Set(sources)],
  };
}

function pickRevisitQuietCopy(allEntries: JournalEntry[], entryId: string): RevisitQuietCopy {
  const entry = allEntries.find((row) => row.id === entryId);
  if (!entry) return REVISIT_QUIET_COPY_EXAMPLES[0];

  const prior = allEntries.filter(
    (row) => new Date(row.createdAt).getTime() < new Date(entry.createdAt).getTime(),
  );
  const themes = new Set(entry.reflection.recurringThemes.map((t) => t.toLowerCase()));
  const priorSameTheme = prior.filter((row) =>
    row.reflection.recurringThemes.some((t) => themes.has(t.toLowerCase())),
  );

  const directNow = /\b(named|decided|clearly|for sure|directly)\b/i.test(entry.transcript);
  const hedgedBefore = priorSameTheme.some((row) =>
    /\b(maybe|sort of|kind of|not sure|vague)\b/i.test(row.transcript),
  );
  if (!directNow && hedgedBefore) {
    return REVISIT_QUIET_COPY_EXAMPLES[3];
  }

  const intenseBefore = priorSameTheme.some((row) => row.reflection.emotionalIntensity >= 6);
  if (intenseBefore && entry.reflection.emotionalIntensity <= 4.5) {
    return REVISIT_QUIET_COPY_EXAMPLES[2];
  }

  if (priorSameTheme.length >= 2) {
    const moodShift =
      priorSameTheme[priorSameTheme.length - 1].reflection.mood !== entry.reflection.mood;
    const intensityDelta = Math.abs(
      entry.reflection.emotionalIntensity -
        priorSameTheme[priorSameTheme.length - 1].reflection.emotionalIntensity,
    );
    if (moodShift || intensityDelta >= 1.5) {
      return REVISIT_QUIET_COPY_EXAMPLES[1];
    }
  }

  return REVISIT_QUIET_COPY_EXAMPLES[0];
}

function pickQuietRealization(
  allEntries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
  exclude: Array<MemoryNote | null | undefined>,
): MemoryNote | null {
  const candidates = [
    ...entryRevisitationNotes(allEntries, entryId),
    ...entryFamiliarityResurfacingNotes(allEntries, entryId, limits.familiarityResurfacing),
    ...entryChangeMomentsNotes(allEntries, entryId, limits.changeMoments),
    ...entryResurfacingNotes(allEntries, entryId, limits.resurfacing),
  ].filter((note) => !exclude.some((row) => isDuplicateNote(note, row)));

  const eligible = rankCallbacksByTuning(candidates, allEntries)
    .map((row) => row.note)
    .filter((note) =>
      shouldAllowEmotionalNote("entry", note, { maxPerSession: 1, minHoursBetween: 1 }),
    );

  const best = pickBestCallback(eligible, allEntries, 42);
  if (best) return best;

  return realizationNote(pickRevisitQuietCopy(allEntries, entryId), entryId);
}

/** Revisit entry presentation — one callback, one then-vs-now, one quiet line. */
export function buildRevisitExperience(
  allEntries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
): RevisitExperiencePresentation {
  const context = detectRevisitContext(entryId);

  if (!context.isRevisit) {
    return {
      isRevisit: false,
      sources: [],
      primaryCallback: null,
      thenVsNow: null,
      quietRealization: null,
      followupPrompt: null,
    };
  }

  markRevisitBoost();

  const notes = entryMemoryNotes(allEntries, entryId);
  const thenVsNowCandidates = notes.thenVsNow.filter(
    (note) => note.pastQuote?.trim() && note.currentQuote?.trim(),
  );
  const thenVsNow = pickBestCallback(thenVsNowCandidates, allEntries, 38);

  const callbackPool = [
    notes.primaryCallback,
    notes.secondaryCallback,
    notes.whatChanged,
    ...entryRevisitationNotes(allEntries, entryId),
    ...entryResurfacingNotes(allEntries, entryId, 1),
  ].filter(Boolean) as MemoryNote[];

  const callbackEligible = rankCallbacksByTuning(callbackPool, allEntries)
    .map((row) => row.note)
    .filter(
      (note) =>
        !isDuplicateNote(note, thenVsNow) &&
        shouldAllowEmotionalNote("entry", note, { maxPerSession: 1, minHoursBetween: 1 }),
    );

  const primaryCallback = pickBestCallback(callbackEligible, allEntries, 48);

  const quietFromPool = pickQuietRealization(allEntries, entryId, limits, [
    primaryCallback,
    thenVsNow,
  ]);
  const knowsMe = entryKnowsMeMoment(allEntries, entryId);
  const quietRealization =
    knowsMe &&
    !isDuplicateNote(knowsMe, primaryCallback) &&
    !isDuplicateNote(knowsMe, thenVsNow)
      ? knowsMe
      : quietFromPool;

  if (primaryCallback) {
    recordEmotionalNoteShown("entry", primaryCallback);
    recordCallbackSurfaced(primaryCallback.id);
  } else if (quietRealization) {
    recordEmotionalNoteShown("entry", quietRealization);
    recordCallbackSurfaced(quietRealization.id);
  }

  const followupPrompt = buildFollowupPrompt(
    [primaryCallback, thenVsNow, quietRealization].filter(Boolean) as MemoryNote[],
  );

  return {
    isRevisit: true,
    sources: context.sources,
    primaryCallback,
    thenVsNow,
    quietRealization:
      quietRealization &&
      !isDuplicateNote(quietRealization, primaryCallback) &&
      !isDuplicateNote(quietRealization, thenVsNow)
        ? quietRealization
        : null,
    followupPrompt,
  };
}

export function trackRevisitOpened(entryId: string, sources: RevisitSource[]): void {
  trackLocalEvent("revisit_opened", {
    entryId,
    sources: sources.join(","),
  });
}

export function trackRevisitThenNowSeen(entryId: string, noteId: string): void {
  trackLocalEvent("revisit_then_now_seen", { entryId, noteId });
}

export function trackRevisitFollowupStarted(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_followup_started", { entryId, promptId });
}
