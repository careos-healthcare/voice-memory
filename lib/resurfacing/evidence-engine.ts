import { getMemoryEligibleEntriesVersion } from "@/lib/storage";
import { assessResurfacingConfidence } from "@/lib/revisit/resurfacing-confidence";
import { assessResurfacingWhyNow } from "@/lib/revisit/resurfacing-why-now";
import {
  isGenericResurfacing,
  passesResurfacingGenericityGate,
  scoreSpecificity,
} from "@/lib/resurfacing/genericity-filter";
import { isBlockedResurfacingCopy, isGenericResurfacingCopy } from "@/lib/revisit/resurfacing-copy";
import { isTopicRecurrenceCopy } from "@/lib/refinement/revisit-reward-copy";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type ConcreteEvidenceKind =
  | "repeated_phrase"
  | "repeated_concern"
  | "named_topic"
  | "mood_shift"
  | "meaningful_gap";

export interface ConcreteResurfacingEvidence {
  backed: boolean;
  kinds: ConcreteEvidenceKind[];
  strength: number;
  whyNow: string | null;
  prefersPhrase: boolean;
}

const WEAK_ONLY_RE =
  /^(you came back to the same (place|loop)|worth revisiting|similar theme|appeared again|showed up again)\.?$/i;

const backedCache = new Map<string, boolean>();

function evidenceCacheKey(noteId: string, entriesVersion: number): string {
  return `${entriesVersion}:${noteId}`;
}

export function clearConcreteEvidenceCache(): void {
  backedCache.clear();
}

function kindsFromSignals(
  whyNow: ReturnType<typeof assessResurfacingWhyNow>,
  confidence: ReturnType<typeof assessResurfacingConfidence>,
): ConcreteEvidenceKind[] {
  const kinds = new Set<ConcreteEvidenceKind>();

  if (whyNow.primaryKind === "repeated_phrase_after_gap" || confidence.evidence.repeatedPhrase) {
    kinds.add("repeated_phrase");
  }
  if (whyNow.primaryKind === "repeated_concern_after_gap" || confidence.evidence.repeatedConcern) {
    kinds.add("repeated_concern");
  }
  if (
    whyNow.primaryKind === "named_person_topic_return" ||
    confidence.evidence.sharedEntities.length > 0
  ) {
    kinds.add("named_topic");
  }
  if (whyNow.primaryKind === "mood_shift_same_topic" || confidence.evidence.moodShift) {
    kinds.add("mood_shift");
  }
  if (confidence.evidence.daysSincePrior >= 3 && kinds.size > 0) {
    kinds.add("meaningful_gap");
  }

  return [...kinds];
}

/** Resurfacing engine v1 — concrete evidence required; phrase beats vague theme. */
export function assessConcreteResurfacingEvidence(
  note: MemoryNote,
  entries: JournalEntry[],
): ConcreteResurfacingEvidence {
  const text = note.text.trim();
  const whyNow = assessResurfacingWhyNow(note, entries);
  const confidence = assessResurfacingConfidence(note, entries);
  const kinds = kindsFromSignals(whyNow, confidence);

  const blocked =
    !text ||
    isBlockedResurfacingCopy(text) ||
    isGenericResurfacingCopy(text) ||
    isGenericResurfacing(text) ||
    isTopicRecurrenceCopy(text) ||
    WEAK_ONLY_RE.test(text) ||
    confidence.suppressed;

  const hasAnchor = kinds.length > 0;
  const hasExplanation = Boolean(whyNow.explanation?.trim());
  const specificityOk = passesResurfacingGenericityGate(text, note, {
    evidenceBacked: whyNow.evidenceBacked,
  });
  const backed =
    !blocked && hasAnchor && hasExplanation && whyNow.evidenceBacked && specificityOk;

  let strength = 0;
  if (kinds.includes("repeated_phrase")) strength += 42;
  if (kinds.includes("repeated_concern")) strength += 28;
  if (kinds.includes("named_topic")) strength += 24;
  if (kinds.includes("mood_shift")) strength += 18;
  if (kinds.includes("meaningful_gap")) strength += 12;
  strength += Math.min(confidence.totalConfidence * 0.35, 28);
  strength += Math.min(scoreSpecificity(text, note) * 0.25, 22);

  return {
    backed,
    kinds,
    strength,
    whyNow: whyNow.explanation,
    prefersPhrase: kinds.includes("repeated_phrase"),
  };
}

export function hasConcreteResurfacingEvidence(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  const key = evidenceCacheKey(note.id, getMemoryEligibleEntriesVersion());
  const cached = backedCache.get(key);
  if (cached !== undefined) return cached;
  const backed = assessConcreteResurfacingEvidence(note, entries).backed;
  backedCache.set(key, backed);
  return backed;
}

export function rankByConcreteEvidence(
  notes: MemoryNote[],
  entries: JournalEntry[],
): Array<{ note: MemoryNote; evidence: ConcreteResurfacingEvidence }> {
  return notes
    .map((note) => ({
      note,
      evidence: assessConcreteResurfacingEvidence(note, entries),
    }))
    .filter((row) => row.evidence.backed)
    .sort((a, b) => {
      if (a.evidence.prefersPhrase !== b.evidence.prefersPhrase) {
        return a.evidence.prefersPhrase ? -1 : 1;
      }
      return b.evidence.strength - a.evidence.strength;
    });
}
