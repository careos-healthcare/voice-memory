import { recordCallbackSurfaced } from "@/lib/callback-interaction-signals";
import { homepageContinuationNotes, recorderPreRecordLine } from "@/lib/conversation/conversation-continuity";
import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import { homepageArchiveGrowthNotes } from "@/lib/memory/archive-growth";
import { homepageContinuityDepthIndicator } from "@/lib/memory/continuity-depth";
import { homepageFamiliarityNotes } from "@/lib/memory/familiarity";
import { homepageFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { homepageMemoryReminder } from "@/lib/memory/memory-reminders";
import { homepageResurfacingNotes } from "@/lib/memory/resurfacing";
import { homepageRevisitationNotes } from "@/lib/memory/revisitation";
import { homepageRhythmNotes } from "@/lib/memory/rhythm-memory";
import { homepageTimeMemoryNotes } from "@/lib/memory/time-memory";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryFamiliarityNotes } from "@/lib/memory/familiarity";
import { entryFamiliarityResurfacingNotes } from "@/lib/memory/familiarity-resurfacing";
import { entryResurfacingNotes } from "@/lib/memory/resurfacing";
import { entryRevisitationNotes } from "@/lib/memory/revisitation";
import { entryTimeMemoryNotes } from "@/lib/memory/time-memory";
import { entryContinuationOpener } from "@/lib/conversation/conversation-continuity";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { pickBestCallback, rankCallbacksByTuning } from "@/lib/refinement/callback-tuning";
import { homepageKnowsMeMoment } from "@/lib/refinement/knows-me-moments";
import { rememberNoteContext } from "@/lib/retention/retention-loops";
import {
  isRevisitEntry,
  markRevisitBoost,
  recordEmotionalNoteShown,
  shouldAllowEmotionalNote,
  suppressResurfacingCluster,
} from "@/lib/refinement/emotional-timing";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { ContinuityDepthIndicator } from "@/types/continuity-depth";
import type { MemoryReminder } from "@/types/memory-reminder";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export interface QuietHomepagePresentation {
  primaryNote: MemoryNote | null;
  continuation: MemoryNote[];
  followupPrompt: FollowupPrompt | null;
  recorderLine: string | null;
  memoryReminder: MemoryReminder | null;
  continuityDepth: ContinuityDepthIndicator | null;
}

export interface QuietEntryPresentation {
  revisitMode: boolean;
  primaryMoment: MemoryNote | null;
  continuation: MemoryNote | null;
  followupPrompt: FollowupPrompt | null;
}

function collectHomepageCandidates(
  entries: JournalEntry[],
  limits: {
    resurfacing: number;
    familiarity: number;
    rhythm: number;
    familiarityResurfacing: number;
  },
): MemoryNote[] {
  return suppressResurfacingCluster([
    ...homepageResurfacingNotes(entries, limits.resurfacing),
    ...homepageRevisitationNotes(entries),
    ...homepageFamiliarityResurfacingNotes(entries, limits.familiarityResurfacing),
    ...homepageFamiliarityNotes(entries, limits.familiarity),
    ...homepageRhythmNotes(entries, limits.rhythm),
    ...homepageTimeMemoryNotes(entries),
  ]);
}

/** Quiet-first homepage: one strong note, one continuation, one follow-up. */
export function buildQuietHomepagePresentation(
  entries: JournalEntry[],
  limits: {
    continuation: number;
    resurfacing: number;
    familiarity: number;
    rhythm: number;
    familiarityResurfacing: number;
    archiveGrowth: number;
  },
): QuietHomepagePresentation {
  const continuation = homepageContinuationNotes(entries, 1).slice(0, 1);
  const candidates = collectHomepageCandidates(entries, limits);

  const eligible = rankCallbacksByTuning(candidates, entries)
    .map((row) => row.note)
    .filter((note) => shouldAllowEmotionalNote("homepage", note));

  const primaryNote = pickBestCallback(eligible, entries, 48);
  const knowsMe = homepageKnowsMeMoment(entries);
  const resolvedPrimary =
    knowsMe && (!primaryNote || knowsMe.confidence >= primaryNote.confidence)
      ? knowsMe
      : primaryNote;

  if (resolvedPrimary) {
    recordEmotionalNoteShown("homepage", resolvedPrimary);
    recordCallbackSurfaced(resolvedPrimary.id);
    if (resolvedPrimary.entryId) {
      rememberNoteContext(
        resolvedPrimary.entryId,
        resolvedPrimary.id,
        resolvedPrimary.text,
      );
    }
  }

  const followupNotes = [...continuation, ...(resolvedPrimary ? [resolvedPrimary] : [])];
  const followupPrompt = buildFollowupPrompt(followupNotes);

  const meaningfulTiming = Boolean(resolvedPrimary);
  const archiveCandidates = homepageArchiveGrowthNotes(entries, meaningfulTiming);
  void archiveCandidates;

  return {
    primaryNote: resolvedPrimary,
    continuation,
    followupPrompt,
    recorderLine: continuation.length === 0 ? recorderPreRecordLine(entries) : null,
    memoryReminder: null,
    continuityDepth: null,
  };
}

function collectEntryCandidates(
  allEntries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarity: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
): MemoryNote[] {
  const notes = entryMemoryNotes(allEntries, entryId);
  const pool: MemoryNote[] = [
    notes.primaryCallback,
    notes.secondaryCallback,
    ...notes.thenVsNow,
    notes.whatChanged,
    ...entryChangeMomentsNotes(allEntries, entryId, limits.changeMoments),
    ...entryFamiliarityNotes(allEntries, entryId, limits.familiarity),
    ...entryFamiliarityResurfacingNotes(allEntries, entryId, limits.familiarityResurfacing),
    ...entryResurfacingNotes(allEntries, entryId, limits.resurfacing),
    ...entryRevisitationNotes(allEntries, entryId),
    ...entryTimeMemoryNotes(allEntries, entryId),
  ].filter(Boolean) as MemoryNote[];

  return suppressResurfacingCluster(pool);
}

/** On revisit, surface one stronger continuity moment. */
export function buildQuietEntryPresentation(
  allEntries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarity: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
): QuietEntryPresentation {
  const revisitMode = isRevisitEntry(entryId);
  if (revisitMode) markRevisitBoost();

  const continuation = entryContinuationOpener(allEntries, entryId);
  const candidates = collectEntryCandidates(allEntries, entryId, limits);

  const eligible = rankCallbacksByTuning(candidates, allEntries)
    .map((row) => row.note)
    .filter((note) =>
      revisitMode
        ? shouldAllowEmotionalNote("entry", note, { maxPerSession: 1, minHoursBetween: 1 })
        : shouldAllowEmotionalNote("entry", note, { maxPerSession: 2, minHoursBetween: 2 }),
    );

  const primaryMoment =
    revisitMode || eligible.length > 0
      ? pickBestCallback(eligible, allEntries, revisitMode ? 52 : 44)
      : null;

  if (primaryMoment) {
    recordEmotionalNoteShown("entry", primaryMoment);
    recordCallbackSurfaced(primaryMoment.id);
  }

  const followupNotes = [
    ...(continuation ? [continuation] : []),
    ...(primaryMoment ? [primaryMoment] : []),
  ];
  const followupPrompt = buildFollowupPrompt(followupNotes);

  return {
    revisitMode,
    primaryMoment,
    continuation: continuation ?? null,
    followupPrompt,
  };
}
