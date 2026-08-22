import { readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning-events";
import {
  cadenceKey,
  emotionalStructureKey,
  RESURFACING_MODE_EVENTS,
} from "@/lib/resurfacing/return-modes";
import {
  getResurfacingFatigueRecord,
  getResurfacingFatigueRecords,
  shouldSuppressResurfacingNote,
} from "@/lib/resurfacing/resurfacing-fatigue";
import { shouldActivateReflexSilenceFirst } from "@/lib/reflex/open-without-record";
import type { MemoryNote } from "@/types/memory-note";

const RECENT_SHOWN_LOOKBACK = 3;
const CALLBACK_COOLDOWN_MS = 48 * 60 * 60 * 1000;
const SIMILAR_IGNORE_THRESHOLD = 2;

const REFLECTION_EVENTS = new Set([
  RESURFACING_MODE_EVENTS.reflectionAfter,
  CALLBACK_LEARNING_EVENTS.reflectionAfter,
  "record_return_opened",
]);

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function recentResurfacingShownEvents(limit = RECENT_SHOWN_LOOKBACK) {
  return readLocalEvents()
    .filter(
      (e) =>
        e.name === RESURFACING_MODE_EVENTS.shown ||
        e.name === CALLBACK_LEARNING_EVENTS.shown,
    )
    .slice(-limit);
}

function noteIdFromEvent(event: { meta?: Record<string, string> }): string | null {
  const id = event.meta?.noteId;
  return typeof id === "string" && id.length > 0 ? id : null;
}

function hadRecordingAfterShown(noteId: string, shownAt: string): boolean {
  const shownMs = new Date(shownAt).getTime();
  return readLocalEvents().some((event) => {
    if (!REFLECTION_EVENTS.has(event.name)) return false;
    if (new Date(event.at).getTime() < shownMs) return false;
    const eventNoteId = noteIdFromEvent(event);
    return eventNoteId === noteId || eventNoteId?.includes(noteId);
  });
}

/** Last N resurfacing shows produced no recording — reduce frequency. */
export function shouldReduceResurfacingFrequency(): boolean {
  const recent = recentResurfacingShownEvents();
  if (recent.length < RECENT_SHOWN_LOOKBACK) return false;
  const withoutRecording = recent.filter((event) => {
    const noteId = noteIdFromEvent(event);
    if (!noteId) return true;
    return !hadRecordingAfterShown(noteId, event.at);
  });
  return withoutRecording.length >= RECENT_SHOWN_LOOKBACK;
}

function similarIgnoredCount(note: MemoryNote): number {
  const cadence = cadenceKey(note.text);
  const structure = emotionalStructureKey(note);
  let count = 0;
  for (const row of getResurfacingFatigueRecords()) {
    const record = getResurfacingFatigueRecord(row.noteId);
    if (!record) continue;
    if (record.ignoredCount + record.repeatedDismissals + record.openedWithoutReflection < 1) {
      continue;
    }
    const events = readLocalEvents().filter(
      (e) =>
        e.name === RESURFACING_MODE_EVENTS.shown &&
        e.meta?.noteId === row.noteId,
    );
    const last = events[events.length - 1];
    if (!last) continue;
    if (last.meta?.cadence === cadence || last.meta?.structure === structure) {
      count += record.ignoredCount + record.repeatedDismissals;
    }
  }
  return count;
}

/** Dismissed or ignored callbacks with similar cadence/structure. */
export function shouldSuppressSimilarResurfacing(note: MemoryNote): boolean {
  if (shouldSuppressResurfacingNote(note.id)) return true;
  return similarIgnoredCount(note) >= SIMILAR_IGNORE_THRESHOLD;
}

/** Shown recently without follow-up recording. */
export function shouldCooldownResurfacing(noteId: string): boolean {
  const row = getResurfacingFatigueRecord(noteId);
  if (!row?.lastShownAt) return false;
  const shownMs = new Date(row.lastShownAt).getTime();
  if (Date.now() - shownMs < CALLBACK_COOLDOWN_MS) {
    if (row.lastReflectionAt) {
      const reflectedMs = new Date(row.lastReflectionAt).getTime();
      if (reflectedMs >= shownMs) return false;
    }
    return true;
  }
  return false;
}

export function shouldSuppressResurfacingByFrequency(note: MemoryNote): boolean {
  if (shouldReduceResurfacingFrequency()) return true;
  if (shouldSuppressSimilarResurfacing(note)) return true;
  if (shouldCooldownResurfacing(note.id)) return true;
  return false;
}

/** Repeated opens without recording — mic-first, no continuity stack. */
export function shouldPreferMicFirstWithoutContinuityStack(): boolean {
  if (!isBrowser()) return false;
  return shouldReduceResurfacingFrequency() || shouldActivateReflexSilenceFirst();
}

/** At most one resurfacing/continuity surface before the recorder. */
export function shouldLimitPromptsBeforeRecorder(surfaceCount: number): boolean {
  return surfaceCount >= 1;
}

export function countHomepagePromptSurfaces(input: {
  primaryNote: MemoryNote | null;
  continuationCount: number;
  followupPrompt: boolean;
  recorderLine: boolean;
}): number {
  let count = 0;
  if (input.primaryNote) count += 1;
  if (input.continuationCount > 0) count += 1;
  if (input.followupPrompt) count += 1;
  if (input.recorderLine) count += 1;
  return count;
}

/** Enforce one prompt max and frequency reduction. */
export function capHomepageResurfacingPresentation<T extends {
  primaryNote: MemoryNote | null;
  continuation: MemoryNote[];
  followupPrompt: unknown;
  recorderLine: string | null;
}>(presentation: T): T & { suppressedReason: string | null } {
  if (shouldPreferMicFirstWithoutContinuityStack()) {
    return {
      ...presentation,
      primaryNote: null,
      continuation: [],
      followupPrompt: null as T["followupPrompt"],
      recorderLine: null,
      suppressedReason: "mic_first_without_stack",
    };
  }

  const surfaces = countHomepagePromptSurfaces({
    primaryNote: presentation.primaryNote,
    continuationCount: presentation.continuation.length,
    followupPrompt: Boolean(presentation.followupPrompt),
    recorderLine: Boolean(presentation.recorderLine),
  });

  if (shouldReduceResurfacingFrequency() && presentation.primaryNote) {
    return {
      ...presentation,
      continuation: [],
      followupPrompt: null as T["followupPrompt"],
      recorderLine: presentation.recorderLine,
      suppressedReason: "reduced_frequency",
    };
  }

  if (shouldLimitPromptsBeforeRecorder(surfaces)) {
    if (presentation.primaryNote) {
      return {
        ...presentation,
        continuation: [],
        followupPrompt: null as T["followupPrompt"],
        suppressedReason: "one_prompt_before_recorder",
      };
    }
    if (presentation.continuation.length > 0) {
      return {
        ...presentation,
        followupPrompt: null as T["followupPrompt"],
        recorderLine: null,
        suppressedReason: "one_prompt_before_recorder",
      };
    }
  }

  return { ...presentation, suppressedReason: null };
}
