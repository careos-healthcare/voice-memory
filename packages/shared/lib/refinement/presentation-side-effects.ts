import { recordCallbackSurfaced } from "@/lib/callback-interaction-signals";
import { markRevisitBoost } from "@/lib/refinement/emotional-timing";
import { recordEmotionalReopen } from "@/lib/refinement/revisit-sequencing";
import type { SilenceSurface } from "@/lib/refinement/silence-calibration";
import { recordSilenceShown } from "@/lib/refinement/silence-calibration";
import { observeMagicCallbackSurfaced } from "@/lib/retention/first-magic-moment";
import { rememberNoteContext } from "@/lib/retention/retention-loops";
import { resolveSilenceIntelligence } from "@/lib/restraint/silence-intelligence";
import { recordResurfacingShown } from "@/lib/resurfacing/resurfacing-fatigue";
import { observeCallbackShown } from "@/lib/revisit/callback-learning";
import { observeResurfacingModeShown } from "@/lib/resurfacing/resurfacing-mode-observation";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type CallbackObservationSurface = "homepage" | "entry";

export interface CallbackObservation {
  note: MemoryNote;
  entries: JournalEntry[];
  surface: CallbackObservationSurface;
  context?: string;
}

export interface SilenceShownObservation {
  note: MemoryNote;
  entries: JournalEntry[];
  surface: SilenceSurface;
}

export interface PresentationSideEffectBatch {
  callbackObservations: CallbackObservation[];
  rememberContexts: Array<{ entryId: string; noteId: string; noteText?: string }>;
  markRevisitBoost: boolean;
  emotionalReopen: { entryId: string; payoffScore: number } | null;
  persistSilenceIntelligence: boolean;
  silenceIntelligenceEntries: JournalEntry[] | null;
}

const deferredSilenceShown: SilenceShownObservation[] = [];

export function emptyPresentationSideEffects(): PresentationSideEffectBatch {
  return {
    callbackObservations: [],
    rememberContexts: [],
    markRevisitBoost: false,
    emotionalReopen: null,
    persistSilenceIntelligence: false,
    silenceIntelligenceEntries: null,
  };
}

export function mergePresentationSideEffects(
  ...batches: PresentationSideEffectBatch[]
): PresentationSideEffectBatch {
  const merged = emptyPresentationSideEffects();
  for (const batch of batches) {
    merged.callbackObservations.push(...batch.callbackObservations);
    merged.rememberContexts.push(...batch.rememberContexts);
    merged.markRevisitBoost ||= batch.markRevisitBoost;
    if (batch.emotionalReopen) merged.emotionalReopen = batch.emotionalReopen;
    merged.persistSilenceIntelligence ||= batch.persistSilenceIntelligence;
    if (batch.silenceIntelligenceEntries) {
      merged.silenceIntelligenceEntries = batch.silenceIntelligenceEntries;
    }
  }
  return merged;
}

export function queueCallbackObservation(
  batch: PresentationSideEffectBatch,
  observation: CallbackObservation,
): void {
  batch.callbackObservations.push(observation);
}

export function queueRememberNoteContext(
  batch: PresentationSideEffectBatch,
  entryId: string,
  noteId: string,
  noteText?: string,
): void {
  batch.rememberContexts.push({ entryId, noteId, noteText });
}

export function queueSilenceIntelligencePersist(
  batch: PresentationSideEffectBatch,
  entries: JournalEntry[],
): void {
  batch.persistSilenceIntelligence = true;
  batch.silenceIntelligenceEntries = entries;
}

export function queueDeferredSilenceShown(
  note: MemoryNote,
  entries: JournalEntry[],
  surface: SilenceSurface,
): void {
  deferredSilenceShown.push({ note, entries, surface });
}

function drainDeferredSilenceShown(): void {
  const pending = deferredSilenceShown.splice(0, deferredSilenceShown.length);
  for (const row of pending) {
    recordSilenceShown(row.note, row.entries, row.surface);
  }
}

function applyCallbackObservation(observation: CallbackObservation): void {
  const { note, entries, surface, context } = observation;
  recordCallbackSurfaced(note.id, surface);
  recordResurfacingShown(note.id);
  observeCallbackShown(note, entries, {
    surface,
    ...(context ? { context } : {}),
  });
  observeResurfacingModeShown(note, entries, { surface });
  observeMagicCallbackSurfaced(note, entries, surface);
}

/** Commit presentation observations after React state has been updated. */
export function flushPresentationSideEffects(batch: PresentationSideEffectBatch): void {
  const hasWork =
    batch.callbackObservations.length > 0 ||
    batch.rememberContexts.length > 0 ||
    batch.markRevisitBoost ||
    batch.emotionalReopen != null ||
    batch.persistSilenceIntelligence ||
    deferredSilenceShown.length > 0;

  if (!hasWork) return;

  const run = () => {
    if (batch.persistSilenceIntelligence && batch.silenceIntelligenceEntries) {
      resolveSilenceIntelligence(batch.silenceIntelligenceEntries);
    }
    if (batch.markRevisitBoost) markRevisitBoost();
    if (batch.emotionalReopen) {
      recordEmotionalReopen(
        batch.emotionalReopen.entryId,
        batch.emotionalReopen.payoffScore,
      );
    }
    for (const observation of batch.callbackObservations) {
      applyCallbackObservation(observation);
    }
    for (const ctx of batch.rememberContexts) {
      rememberNoteContext(ctx.entryId, ctx.noteId, ctx.noteText);
    }
    drainDeferredSilenceShown();
  };

  if (typeof queueMicrotask === "function") {
    queueMicrotask(run);
  } else {
    run();
  }
}

/** Strip side-effect payloads before caching presentations. */
export function withoutPresentationSideEffects<T extends { sideEffects: PresentationSideEffectBatch }>(
  presentation: T,
): T {
  return { ...presentation, sideEffects: emptyPresentationSideEffects() };
}
