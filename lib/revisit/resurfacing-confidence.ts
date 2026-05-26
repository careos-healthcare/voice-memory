import {
  callbackInteractionSignals,
  readCallbackRetention,
  summarizeCallbackRetention,
} from "@/lib/callback-interaction-signals";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { isTopicRecurrenceCopy } from "@/lib/refinement/knows-me-moments";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  isBlockedResurfacingCopy,
  isGenericResurfacingCopy,
  isMoodOrThemeOnlyResurface,
  pickResurfacingEvidenceReason,
} from "@/lib/revisit/resurfacing-copy";
import {
  collectRevisitQualityCandidates,
  isRevisitQualityNote,
} from "@/lib/revisit/revisit-quality";
import type { JournalEntry } from "@/types/journal";
import type { Reflection } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  ResurfacingConfidenceClassification,
  ResurfacingConfidenceDimensions,
  ResurfacingConfidenceEvidence,
  ResurfacingConfidenceVerdict,
} from "@/types/resurfacing-confidence";

export const CONFIDENCE_SUPPRESS_MAX = 54;
export const CONFIDENCE_PLAUSIBLE_MIN = 55;
export const CONFIDENCE_STRONG_MIN = 70;
export const CONFIDENCE_MAGIC_MIN = 80;

const GENERIC_MOOD_ONLY_RE =
  /\b(felt (anxious|sad|low|down|stressed|tired)|mood|energy level|overall feeling)\b/i;

const UNUSUAL_WORDING_RE =
  /\b(i guess|sort of|maybe|probably|not sure|i keep|same loop|circling|i'm not|i am not)\b/i;

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function referencesPriorReflection(note: MemoryNote, entries: JournalEntry[]): boolean {
  if (note.pastEntryId?.trim() || note.pastQuote?.trim()) return true;
  if (!note.entryId?.trim()) return false;
  const target = entryById(entries, note.entryId);
  if (!target) return false;
  const targetMs = new Date(target.createdAt).getTime();
  return entries.some(
    (entry) =>
      entry.id !== note.entryId &&
      new Date(entry.createdAt).getTime() < targetMs - 24 * 60 * 60 * 1000,
  );
}

function scoreRepeatedPhrase(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  let score = 0;

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    const sim = quoteSimilarity(note.pastQuote, note.currentQuote);
    if (sim >= 0.45) score += 38;
    else if (sim >= 0.28) score += 22;
  }

  if (past && current) {
    const phrases = buildPhraseMemory(entries);
    const gap = gapDaysForNote(note, entries);
    for (const record of phrases) {
      if (record.count < 2) continue;
      if (!record.entryIds.includes(past.id) || !record.entryIds.includes(current.id)) continue;
      score += 28 + Math.min(record.count * 5, 20);
      if (gap >= 7) score += 18;
      if (gap >= 14) score += 10;
      if (record.phrase.length >= 14 || UNUSUAL_WORDING_RE.test(record.phrase)) score += 12;
    }
  }

  if (/phrase|knows-me-phrase/i.test(note.id)) score += 24;
  if (past?.reflection.exactLanguagePattern?.trim() || current?.reflection.exactLanguagePattern?.trim()) {
    score += 14;
  }

  return Math.min(score, 100);
}

function sharedRecurringThemes(past: Reflection, current: Reflection): string[] {
  const currentSet = new Set(current.recurringThemes.map((theme) => theme.toLowerCase()));
  return past.recurringThemes.filter((theme) => currentSet.has(theme.toLowerCase()));
}

function sharedConcernSignals(past: Reflection, current: Reflection): string[] {
  const matches: string[] = [];
  if (past.hiddenConcern?.trim() && current.hiddenConcern?.trim()) {
    const left = past.hiddenConcern.toLowerCase();
    const right = current.hiddenConcern.toLowerCase();
    if (left === right || tokenOverlap(left, right) >= 0.35) {
      matches.push(past.hiddenConcern);
    }
  }
  if (past.concreteObservation?.trim() && current.concreteObservation?.trim()) {
    if (tokenOverlap(past.concreteObservation, current.concreteObservation) >= 0.22) {
      matches.push(past.concreteObservation);
    }
  }
  return matches;
}

function scoreEmotionalRecurrence(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;

  let score = 0;
  const sharedThemes = sharedRecurringThemes(past.reflection, current.reflection);
  const sharedConcerns = sharedConcernSignals(past.reflection, current.reflection);

  if (sharedConcerns.length > 0) score += 34 + sharedConcerns.length * 8;
  if (sharedThemes.length > 0 && sharedConcerns.length === 0) score += 12;

  const intensityDelta = Math.abs(
    past.reflection.emotionalIntensity - current.reflection.emotionalIntensity,
  );
  const moodShift =
    past.reflection.mood !== current.reflection.mood || intensityDelta >= 1.2;

  if (moodShift && (sharedConcerns.length > 0 || sharedThemes.length > 0)) {
    score += 22;
  } else if (moodShift && sharedThemes.length === 0 && sharedConcerns.length === 0) {
    score -= 18;
  }

  if (/topic|entity|loop|concern|resurface-/i.test(note.id)) score += 16;

  const pastText = `${past.transcript} ${past.reflection.concreteObservation ?? ""}`;
  const currentText = `${current.transcript} ${current.reflection.concreteObservation ?? ""}`;
  if (GENERIC_MOOD_ONLY_RE.test(pastText) && GENERIC_MOOD_ONLY_RE.test(currentText) && !sharedConcerns.length) {
    score -= 28;
  }

  return Math.max(0, Math.min(score, 100));
}

function scoreTemporalDistance(gapDays: number, evidenceMatches: boolean): number {
  if (gapDays <= 0) return 8;
  if (gapDays < 3) return 22;
  if (gapDays < 7) return 48;
  if (gapDays < 14) return 72;
  if (evidenceMatches) return 92;
  return 58;
}

function tokenOverlap(a: string, b: string): number {
  const left = new Set(a.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  const right = new Set(b.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
}

function scoreSemanticSimilarity(note: MemoryNote, entries: JournalEntry[]): {
  score: number;
  sharedEntities: string[];
} {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return { score: 0, sharedEntities: [] };

  const entityReport = buildEntityMemoryFromEntries(entries);
  const linkedIds = new Set([past.id, current.id]);
  const sharedEntities = [
    ...entityReport.people,
    ...entityReport.concerns,
    ...entityReport.topics,
  ]
    .filter((row) => row.entryIds.some((id) => linkedIds.has(id)))
    .map((row) => row.name)
    .slice(0, 6);

  let independentSignals = 0;
  let score = 0;

  if (sharedEntities.length > 0) {
    score += 24 + sharedEntities.length * 8;
    independentSignals += 1;
  }

  const sharedConcerns = sharedConcernSignals(past.reflection, current.reflection);
  if (sharedConcerns.length > 0) {
    score += 20;
    independentSignals += 1;
  }

  const transcriptOverlap = tokenOverlap(past.transcript, current.transcript);
  if (transcriptOverlap >= 0.18) {
    score += Math.round(transcriptOverlap * 80);
    independentSignals += 1;
  }

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    score += 12;
    independentSignals += 1;
  }

  if (independentSignals < 2 && sharedEntities.length === 0 && sharedConcerns.length === 0) {
    score = Math.min(score, 28);
  }

  return { score: Math.min(score, 100), sharedEntities };
}

function scoreInteractionReinforcement(note: MemoryNote, entries: JournalEntry[]): number {
  const entryIds = linkedEntriesForNote(note, entries).map((row) => row.id);
  const signals = callbackInteractionSignals(note.id, entryIds);
  const retention = summarizeCallbackRetention(note.id, entryIds);
  const ignored = readCallbackRetention(note.id).filter((row) => row.outcome === "ignored").length;

  let score = 40;
  if (signals.revisitCount > 0) score += 14;
  if (signals.rereadCount > 0) score += 10;
  if (signals.bookmarked) score += 16;
  if (signals.memoryMomentCopied) score += 14;
  if (signals.followupContinued) score += 18;
  if (retention.recording > 0) score += 12;
  score -= Math.min(ignored * 14, 42);

  return Math.max(0, Math.min(score, 100));
}

function collectEvidence(
  note: MemoryNote,
  entries: JournalEntry[],
  dimensions: ResurfacingConfidenceDimensions,
  sharedEntities: string[],
): ResurfacingConfidenceEvidence {
  const gapDays = gapDaysForNote(note, entries);
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  const moodShift =
    Boolean(past && current) &&
    (past!.reflection.mood !== current!.reflection.mood ||
      Math.abs(past!.reflection.emotionalIntensity - current!.reflection.emotionalIntensity) >=
        1.2);

  const entryIds = linkedEntriesForNote(note, entries).map((row) => row.id);
  const signals = callbackInteractionSignals(note.id, entryIds);
  const sharedConcerns =
    past && current ? sharedConcernSignals(past.reflection, current.reflection) : [];

  return {
    repeatedPhrase: dimensions.repeatedPhraseScore >= 52,
    repeatedConcern:
      dimensions.emotionalRecurrenceScore >= 50 && sharedConcerns.length > 0,
    moodShift,
    daysSincePrior: gapDays,
    sharedEntities,
    priorInteraction:
      signals.revisitCount > 0 ||
      signals.bookmarked ||
      signals.memoryMomentCopied ||
      signals.followupContinued,
  };
}

function countEvidenceSignals(evidence: ResurfacingConfidenceEvidence): number {
  let count = 0;
  if (evidence.repeatedPhrase) count += 1;
  if (evidence.repeatedConcern) count += 1;
  if (evidence.moodShift) count += 1;
  if (evidence.daysSincePrior >= 3) count += 1;
  if (evidence.sharedEntities.length > 0) count += 1;
  if (evidence.priorInteraction) count += 1;
  return count;
}

function answersWhyNow(
  evidence: ResurfacingConfidenceEvidence,
  dimensions: ResurfacingConfidenceDimensions,
): boolean {
  if (evidence.repeatedPhrase || evidence.repeatedConcern) return true;
  if (evidence.moodShift && evidence.daysSincePrior >= 3) return true;
  if (evidence.daysSincePrior >= 7 && dimensions.semanticSimilarityScore >= 45) return true;
  return false;
}

function buildFalsePositiveRisks(
  note: MemoryNote,
  evidence: ResurfacingConfidenceEvidence,
  dimensions: ResurfacingConfidenceDimensions,
  hasPriorReflection: boolean,
): string[] {
  const risks: string[] = [];
  if (!hasPriorReflection) risks.push("no_prior_reflection");
  if (evidence.daysSincePrior < 3) risks.push("same_day_or_no_gap");
  if (dimensions.emotionalRecurrenceScore < 35 && evidence.moodShift) risks.push("mood_only_match");
  if (dimensions.semanticSimilarityScore < 30) risks.push("theme_only_similarity");
  if (isGenericResurfacingCopy(note.text)) risks.push("generic_copy");
  if (isTopicRecurrenceCopy(note.text)) risks.push("topic_recurrence_template");
  if (dimensions.interactionReinforcementScore < 25) risks.push("ignored_or_dismissed");
  return risks;
}

function classifyConfidence(
  total: number,
  evidence: ResurfacingConfidenceEvidence,
  evidenceSignalCount: number,
  suppressReasons: string[],
  hasPriorReflection: boolean,
  interactionPotential: boolean,
): ResurfacingConfidenceClassification {
  if (suppressReasons.length > 0 || total <= CONFIDENCE_SUPPRESS_MAX) return "suppress";
  if (
    total >= CONFIDENCE_MAGIC_MIN &&
    hasPriorReflection &&
    (interactionPotential || evidenceSignalCount >= 2)
  ) {
    return "magic_candidate";
  }
  if (
    total >= CONFIDENCE_STRONG_MIN &&
    (evidence.repeatedPhrase || evidence.repeatedConcern)
  ) {
    return "strong";
  }
  if (total >= CONFIDENCE_PLAUSIBLE_MIN && evidenceSignalCount >= 2) return "plausible";
  if (total >= CONFIDENCE_PLAUSIBLE_MIN) return "weak";
  return "suppress";
}

/** Score whether a callback is earned enough to surface — internal only. */
export function assessResurfacingConfidence(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingConfidenceVerdict {
  const text = note.text.trim();
  const gapDays = gapDaysForNote(note, entries);
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  const hasPriorReflection = referencesPriorReflection(note, entries);

  const repeatedPhraseScore = scoreRepeatedPhrase(note, entries);
  const emotionalRecurrenceScore = scoreEmotionalRecurrence(note, entries);
  const { score: semanticSimilarityScore, sharedEntities } = scoreSemanticSimilarity(
    note,
    entries,
  );
  const evidenceMatches =
    repeatedPhraseScore >= 45 ||
    emotionalRecurrenceScore >= 45 ||
    semanticSimilarityScore >= 45;
  const temporalDistanceScore = scoreTemporalDistance(gapDays, evidenceMatches);
  const interactionReinforcementScore = scoreInteractionReinforcement(note, entries);

  const dimensions: ResurfacingConfidenceDimensions = {
    repeatedPhraseScore,
    emotionalRecurrenceScore,
    temporalDistanceScore,
    semanticSimilarityScore,
    interactionReinforcementScore,
  };

  const evidence = collectEvidence(note, entries, dimensions, sharedEntities);
  const evidenceSignalCount = countEvidenceSignals(evidence);

  const totalConfidence = Math.round(
    repeatedPhraseScore * 0.24 +
      emotionalRecurrenceScore * 0.22 +
      temporalDistanceScore * 0.18 +
      semanticSimilarityScore * 0.22 +
      interactionReinforcementScore * 0.14,
  );

  const suppressReasons: string[] = [];
  const reasons: string[] = [];

  if (isBlockedResurfacingCopy(text) || isGenericResurfacingCopy(text)) {
    suppressReasons.push("generic_copy");
  }
  if (isTopicRecurrenceCopy(text)) suppressReasons.push("topic_recurrence_template");
  if (!hasPriorReflection) suppressReasons.push("no_prior_reflection");
  if (!answersWhyNow(evidence, dimensions)) suppressReasons.push("no_why_now");
  if (
    past &&
    current &&
    note.id.includes("topic_silence") &&
    isMoodOrThemeOnlyResurface("topic_silence", past, current) &&
    !evidence.repeatedPhrase &&
    !evidence.repeatedConcern
  ) {
    suppressReasons.push("mood_only_match");
  }
  if (gapDays <= 0 && !evidence.repeatedPhrase) suppressReasons.push("same_day_no_phrase");

  if (evidence.repeatedPhrase) reasons.push("repeated_phrase");
  if (evidence.repeatedConcern) reasons.push("repeated_concern");
  if (evidence.moodShift) reasons.push("mood_shift");
  if (evidence.daysSincePrior >= 7) reasons.push("time_gap_7d");
  else if (evidence.daysSincePrior >= 3) reasons.push("time_gap_3d");
  if (evidence.sharedEntities.length > 0) reasons.push("shared_entities");
  if (evidence.priorInteraction) reasons.push("prior_interaction");

  const interactionPotential =
    interactionReinforcementScore >= 52 || evidence.priorInteraction;

  const classification = classifyConfidence(
    totalConfidence,
    evidence,
    evidenceSignalCount,
    suppressReasons,
    hasPriorReflection,
    interactionPotential,
  );

  const falsePositiveRisks = buildFalsePositiveRisks(
    note,
    evidence,
    dimensions,
    hasPriorReflection,
  );

  const evidenceReason = pickResurfacingEvidenceReason(evidence, gapDays);

  return {
    noteId: note.id,
    entryId: note.entryId,
    text,
    totalConfidence,
    classification,
    dimensions,
    evidence,
    evidenceSignalCount,
    reasons,
    suppressReasons,
    evidenceReason,
    falsePositiveRisks,
    suppressed: classification === "suppress",
  };
}

export function shouldSuppressResurfacingConfidence(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  if (!isRevisitQualityNote(note) && !note.id.includes("resurface")) {
    return false;
  }
  return assessResurfacingConfidence(note, entries).suppressed;
}

export function pickConfidenceEligibleNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
): MemoryNote[] {
  return notes.filter((note) => !shouldSuppressResurfacingConfidence(note, entries));
}

export function enrichNoteWithResurfacingConfidence(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote {
  const verdict = assessResurfacingConfidence(note, entries);
  if (verdict.suppressed || !verdict.evidenceReason) return note;
  return {
    ...note,
    evidenceReason: verdict.evidenceReason,
  };
}

export function applyResurfacingConfidenceRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  const verdict = assessResurfacingConfidence(note, entries);
  if (verdict.suppressed) return baseScore - 50;
  if (verdict.classification === "weak") return baseScore - 12;
  if (verdict.classification === "plausible") return baseScore + 6;
  if (verdict.classification === "strong") return baseScore + 14;
  if (verdict.classification === "magic_candidate") return baseScore + 22;
  return baseScore;
}

export function collectResurfacingConfidenceCandidates(
  entries: JournalEntry[],
): MemoryNote[] {
  return collectRevisitQualityCandidates(entries);
}
