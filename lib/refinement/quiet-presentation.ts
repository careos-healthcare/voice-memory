import { homepageContinuationNotes, recorderPreRecordLine } from "@/lib/conversation/conversation-continuity";
import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import { pickArchiveDepthIndicator } from "@/lib/memory/continuity-depth";
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
import {
  bestInterruptionMode,
  recordInterruptionShown,
  shouldInterruptNow,
  shouldStaySilent,
} from "@/lib/capture/interruption-timing";
import { capHomepageResurfacingPresentation } from "@/lib/resurfacing/resurfacing-frequency";
import { naturalizeResurfacingNote } from "@/lib/resurfacing/resurfacing-natural-voice";
import { pickQualityRevisitNotes } from "@/lib/revisit/revisit-quality";
import {
  enrichNoteWithResurfacingConfidence,
  pickConfidenceEligibleNotes,
} from "@/lib/revisit/resurfacing-confidence";
import { homepageKnowsMeMoment } from "@/lib/refinement/knows-me-moments";
import {
  emptyPresentationSideEffects,
  queueCallbackObservation,
  queueRememberNoteContext,
  queueSilenceIntelligencePersist,
  type PresentationSideEffectBatch,
} from "@/lib/refinement/presentation-side-effects";
import {
  calibrateEntryPresentation,
  calibrateHomepagePresentation,
} from "@/lib/refinement/silence-calibration";
import {
  firstAhaAsMemoryNote,
  pickFirstAhaCallback,
} from "@/lib/onboarding/first-aha-callback";
import {
  isRevisitEntry,
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
  sideEffects: PresentationSideEffectBatch;
}

export interface QuietEntryPresentation {
  revisitMode: boolean;
  primaryMoment: MemoryNote | null;
  continuation: MemoryNote | null;
  followupPrompt: FollowupPrompt | null;
  sideEffects: PresentationSideEffectBatch;
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
  const sideEffects = emptyPresentationSideEffects();
  queueSilenceIntelligencePersist(sideEffects, entries);
  const continuation = homepageContinuationNotes(entries, 1).slice(0, 1);
  const candidates = collectHomepageCandidates(entries, limits);

  const eligible = pickConfidenceEligibleNotes(
    pickQualityRevisitNotes(
      rankCallbacksByTuning(candidates, entries).map((row) => row.note),
      entries,
    ),
    entries,
  ).filter((note) => shouldAllowEmotionalNote("homepage", note));

  const firstAha = pickFirstAhaCallback(entries);
  const primaryNote =
    shouldStaySilent() || !shouldInterruptNow()
      ? null
      : pickBestCallback(eligible, entries, 48);
  if (primaryNote) {
    recordInterruptionShown(bestInterruptionMode());
  }
  const knowsMe = homepageKnowsMeMoment(entries);
  const resolvedPrimaryRaw = firstAha
    ? firstAhaAsMemoryNote(firstAha)
    : knowsMe && (!primaryNote || knowsMe.confidence >= primaryNote.confidence)
      ? knowsMe
      : primaryNote;
  const resolvedPrimary = resolvedPrimaryRaw
    ? enrichNoteWithResurfacingConfidence(resolvedPrimaryRaw, entries)
    : null;

  if (resolvedPrimary) {
    queueCallbackObservation(sideEffects, {
      note: resolvedPrimary,
      entries,
      surface: "homepage",
    });
    if (resolvedPrimary.entryId) {
      queueRememberNoteContext(
        sideEffects,
        resolvedPrimary.entryId,
        resolvedPrimary.id,
        resolvedPrimary.text,
      );
    }
  }

  const calibrated = calibrateHomepagePresentation(
    {
      primaryNote: resolvedPrimary
        ? naturalizeResurfacingNote(resolvedPrimary, entries)
        : null,
      continuation,
      followupPrompt: null,
      recorderLine: continuation.length === 0 ? recorderPreRecordLine(entries) : null,
      memoryReminder: null,
      continuityDepth: pickArchiveDepthIndicator(entries, "homepage"),
    },
    entries,
  );

  const withFollowup = {
    ...calibrated,
    followupPrompt: buildFollowupPrompt(
      calibrated.primaryNote ? [calibrated.primaryNote] : [],
      entries,
    ),
  };

  const capped = capHomepageResurfacingPresentation(withFollowup);

  return {
    ...capped,
    sideEffects,
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
  const sideEffects = emptyPresentationSideEffects();
  queueSilenceIntelligencePersist(sideEffects, allEntries);
  const revisitMode = isRevisitEntry(entryId);
  if (revisitMode) sideEffects.markRevisitBoost = true;

  const continuation = entryContinuationOpener(allEntries, entryId);
  const candidates = collectEntryCandidates(allEntries, entryId, limits);

  const eligible = pickConfidenceEligibleNotes(
    pickQualityRevisitNotes(
      rankCallbacksByTuning(candidates, allEntries).map((row) => row.note),
      allEntries,
    ),
    allEntries,
  ).filter((note) =>
    revisitMode
      ? shouldAllowEmotionalNote("entry", note, { maxPerSession: 1, minHoursBetween: 1 })
      : shouldAllowEmotionalNote("entry", note, { maxPerSession: 2, minHoursBetween: 2 }),
  );

  const primaryMomentRaw =
    revisitMode || eligible.length > 0
      ? pickBestCallback(eligible, allEntries, revisitMode ? 52 : 44)
      : null;
  const primaryMoment = primaryMomentRaw
    ? naturalizeResurfacingNote(
        enrichNoteWithResurfacingConfidence(primaryMomentRaw, allEntries),
        allEntries,
      )
    : null;

  if (primaryMoment) {
    queueCallbackObservation(sideEffects, {
      note: primaryMoment,
      entries: allEntries,
      surface: "entry",
    });
  }

  const followupNotes = [
    ...(continuation ? [continuation] : []),
    ...(primaryMoment ? [primaryMoment] : []),
  ];

  const calibrated = calibrateEntryPresentation(
    {
      revisitMode,
      primaryMoment,
      continuation: continuation ?? null,
      followupPrompt: null,
    },
    allEntries,
  );

  return {
    ...calibrated,
    followupPrompt: buildFollowupPrompt(
      calibrated.primaryMoment ? [calibrated.primaryMoment] : followupNotes,
      allEntries,
      entryId,
    ),
    sideEffects,
  };
}
