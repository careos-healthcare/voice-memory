import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  formatGapLabel,
  isBlockedResurfacingCopy,
  isGenericResurfacingCopy,
  RESURFACING_WHY_NOW_COPY,
} from "@/lib/revisit/resurfacing-copy";
import { collectResurfacingConfidenceCandidates } from "@/lib/revisit/resurfacing-confidence";
import type { JournalEntry, Reflection } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  ResurfacingWhyNowKind,
  ResurfacingWhyNowSignal,
  ResurfacingWhyNowVerdict,
} from "@/types/resurfacing-why-now";

const MIN_GAP_DAYS = 3;
const QUIET_GAP_DAYS = 7;

const AVOIDANCE_PHRASE_RE =
  /\b(stuff|things|something|someone|that situation|that thing|i guess|sort of|maybe|probably|not sure|don't know|do not know|circling|avoiding|hard to say)\b/i;

const FUTURE_PHRASE_RE =
  /\b(will|going to|gonna|soon|next week|next month|plan to|hope to|want to|need to|looking forward|when i|if i|eventually|someday)\b/i;

const GENERIC_INSIGHT_RE =
  /\b(insight|pattern|intelligence|continuity|mirror|journey|healing|unpack|process this)\b/i;

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

function dayOfWeek(iso: string): number {
  return new Date(iso).getDay();
}

function timeBucket(iso: string): "morning" | "afternoon" | "evening" | "night" {
  const hour = new Date(iso).getHours();
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

function timeBucketLabel(bucket: ReturnType<typeof timeBucket>): string {
  switch (bucket) {
    case "morning":
      return "morning";
    case "afternoon":
      return "afternoon";
    case "evening":
      return "evening";
    case "night":
      return "night";
  }
}

function tokenOverlap(a: string, b: string): number {
  const left = new Set(a.toLowerCase().split(/\s+/).filter((word) => word.length > 3));
  const right = new Set(b.toLowerCase().split(/\s+/).filter((word) => word.length > 3));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
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

function sharedEntitiesBetween(
  past: JournalEntry,
  current: JournalEntry,
  entries: JournalEntry[],
): { name: string; type: "person" | "topic" }[] {
  const report = buildEntityMemoryFromEntries(entries);
  const linkedIds = new Set([past.id, current.id]);
  const matches: { name: string; type: "person" | "topic" }[] = [];

  for (const entity of report.people) {
    if (entity.entryIds.filter((id) => linkedIds.has(id)).length >= 2) {
      matches.push({ name: entity.name, type: "person" });
    }
  }
  for (const entity of [...report.concerns, ...report.topics]) {
    if (entity.entryIds.filter((id) => linkedIds.has(id)).length >= 2) {
      matches.push({ name: entity.name, type: "topic" });
    }
  }
  return matches.slice(0, 3);
}

function repeatedPhraseBetween(
  note: MemoryNote,
  past: JournalEntry,
  current: JournalEntry,
  entries: JournalEntry[],
): { matched: boolean; phrase?: string } {
  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    if (quoteSimilarity(note.pastQuote, note.currentQuote) >= 0.28) {
      return { matched: true, phrase: note.pastQuote.slice(0, 80) };
    }
  }

  const phrases = buildPhraseMemory(entries);
  for (const record of phrases) {
    if (record.count < 2) continue;
    if (!record.entryIds.includes(past.id) || !record.entryIds.includes(current.id)) continue;
    return { matched: true, phrase: record.phrase };
  }

  if (/phrase|knows-me-phrase/i.test(note.id)) {
    return { matched: true };
  }

  return { matched: false };
}

function repeatedLanguageInPair(
  past: JournalEntry,
  current: JournalEntry,
  pattern: RegExp,
): { matched: boolean; phrase?: string } {
  const pastText = `${past.transcript} ${past.reflection.exactLanguagePattern ?? ""}`;
  const currentText = `${current.transcript} ${current.reflection.exactLanguagePattern ?? ""}`;
  const pastMatch = pastText.match(pattern);
  const currentMatch = currentText.match(pattern);
  if (!pastMatch || !currentMatch) return { matched: false };
  if (pastMatch[0].toLowerCase() === currentMatch[0].toLowerCase()) {
    return { matched: true, phrase: pastMatch[0] };
  }
  return { matched: true, phrase: currentMatch[0] };
}

function hasQuietStretchBetween(
  past: JournalEntry,
  current: JournalEntry,
  entries: JournalEntry[],
): boolean {
  const pastMs = new Date(past.createdAt).getTime();
  const currentMs = new Date(current.createdAt).getTime();
  const between = entries.filter((entry) => {
    const ms = new Date(entry.createdAt).getTime();
    return ms > pastMs && ms < currentMs;
  });
  return between.length === 0 || between.length <= 1;
}

function detectWhyNowSignals(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingWhyNowSignal[] {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return [];

  const gapDays = gapDaysForNote(note, entries);
  const signals: ResurfacingWhyNowSignal[] = [];

  const phraseMatch = repeatedPhraseBetween(note, past, current, entries);
  if (phraseMatch.matched && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "repeated_phrase_after_gap",
      strength: 92 + Math.min(gapDays, 14),
      evidence: ["phrase_match", `gap_${gapDays}d`],
      gapDays,
      phrase: phraseMatch.phrase,
    });
  }

  const sharedConcerns = sharedConcernSignals(past.reflection, current.reflection);
  if (sharedConcerns.length > 0 && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "repeated_concern_after_gap",
      strength: 84 + sharedConcerns.length * 4,
      evidence: ["concern_overlap", `gap_${gapDays}d`],
      gapDays,
    });
  }

  const entities = sharedEntitiesBetween(past, current, entries);
  if (entities.length > 0 && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "named_person_topic_return",
      strength: 86 + gapDays,
      evidence: ["shared_entity", entities[0].type, `gap_${gapDays}d`],
      gapDays,
      entityName: entities[0].name,
    });
  }

  const sharedThemes = sharedRecurringThemes(past.reflection, current.reflection);
  const moodShift =
    past.reflection.mood !== current.reflection.mood ||
    Math.abs(past.reflection.emotionalIntensity - current.reflection.emotionalIntensity) >= 1.2;

  if (moodShift && (sharedThemes.length > 0 || sharedConcerns.length > 0) && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "mood_shift_same_topic",
      strength: 78 + (sharedThemes.length + sharedConcerns.length) * 3,
      evidence: ["mood_shift", "shared_topic", `gap_${gapDays}d`],
      gapDays,
    });
  }

  if (
    past.reflection.mood === current.reflection.mood &&
    gapDays >= MIN_GAP_DAYS &&
    (sharedThemes.length > 0 || sharedConcerns.length > 0)
  ) {
    signals.push({
      kind: "same_emotional_state",
      strength: 68 + gapDays,
      evidence: ["same_mood", `gap_${gapDays}d`],
      gapDays,
    });
  }

  const avoidance = repeatedLanguageInPair(past, current, AVOIDANCE_PHRASE_RE);
  if (avoidance.matched && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "repeated_avoidance_language",
      strength: 74,
      evidence: ["avoidance_phrase", `gap_${gapDays}d`],
      gapDays,
      phrase: avoidance.phrase,
    });
  }

  const future = repeatedLanguageInPair(past, current, FUTURE_PHRASE_RE);
  if (future.matched && gapDays >= MIN_GAP_DAYS) {
    signals.push({
      kind: "repeated_future_language",
      strength: 72,
      evidence: ["future_phrase", `gap_${gapDays}d`],
      gapDays,
      phrase: future.phrase,
    });
  }

  if (
    gapDays >= QUIET_GAP_DAYS &&
    (sharedThemes.length > 0 || sharedConcerns.length > 0 || entities.length > 0) &&
    hasQuietStretchBetween(past, current, entries)
  ) {
    signals.push({
      kind: "quiet_gap_return",
      strength: 76 + gapDays,
      evidence: ["quiet_gap", `gap_${gapDays}d`],
      gapDays,
    });
  }

  if (dayOfWeek(past.createdAt) === dayOfWeek(current.createdAt) && gapDays >= MIN_GAP_DAYS) {
    const hasTopicAnchor =
      sharedThemes.length > 0 || sharedConcerns.length > 0 || entities.length > 0 || phraseMatch.matched;
    if (hasTopicAnchor) {
      signals.push({
        kind: "same_weekday",
        strength: 64 + gapDays,
        evidence: ["same_weekday", `gap_${gapDays}d`],
        gapDays,
      });
    }
  }

  const pastBucket = timeBucket(past.createdAt);
  const currentBucket = timeBucket(current.createdAt);
  if (pastBucket === currentBucket && gapDays >= MIN_GAP_DAYS) {
    const hasTopicAnchor =
      sharedThemes.length > 0 || sharedConcerns.length > 0 || entities.length > 0 || phraseMatch.matched;
    if (hasTopicAnchor) {
      signals.push({
        kind: "same_time_of_day",
        strength: 62 + gapDays,
        evidence: ["same_time_bucket", pastBucket, `gap_${gapDays}d`],
        gapDays,
      });
    }
  }

  return signals.sort((a, b) => b.strength - a.strength);
}

function explanationForSignal(signal: ResurfacingWhyNowSignal): string {
  const gapDays = signal.gapDays ?? 0;
  switch (signal.kind) {
    case "repeated_phrase_after_gap":
      return RESURFACING_WHY_NOW_COPY.similarWordsDaysAgo(gapDays);
    case "repeated_concern_after_gap":
      return gapDays >= QUIET_GAP_DAYS
        ? RESURFACING_WHY_NOW_COPY.concernAfterQuietStretch
        : RESURFACING_WHY_NOW_COPY.concernAgainAfterGap(gapDays);
    case "named_person_topic_return":
      if (signal.entityName) {
        return signal.evidence.includes("person")
          ? RESURFACING_WHY_NOW_COPY.personAgainAfterDays(signal.entityName, gapDays)
          : RESURFACING_WHY_NOW_COPY.topicAgainAfterDays(signal.entityName, gapDays);
      }
      return RESURFACING_WHY_NOW_COPY.topicAgainAfterDays("this", gapDays);
    case "mood_shift_same_topic":
      return RESURFACING_WHY_NOW_COPY.toneChangedSameTopic;
    case "same_emotional_state":
      return RESURFACING_WHY_NOW_COPY.sameEmotionalStateReturn(gapDays);
    case "quiet_gap_return":
      return RESURFACING_WHY_NOW_COPY.concernAfterQuietStretch;
    case "repeated_avoidance_language":
      return RESURFACING_WHY_NOW_COPY.repeatedAvoidanceLanguage(gapDays);
    case "repeated_future_language":
      return RESURFACING_WHY_NOW_COPY.repeatedFutureLanguage(gapDays);
    case "same_weekday":
      return RESURFACING_WHY_NOW_COPY.sameKindOfDay;
    case "same_time_of_day": {
      const bucket = signal.evidence.find((item) =>
        ["morning", "afternoon", "evening", "night"].includes(item),
      );
      return bucket
        ? RESURFACING_WHY_NOW_COPY.sameTimeOfDay(timeBucketLabel(bucket as ReturnType<typeof timeBucket>))
        : RESURFACING_WHY_NOW_COPY.sameKindOfDay;
    }
    default:
      return RESURFACING_WHY_NOW_COPY.cameBackAfterGap(gapDays);
  }
}

function isValidExplanation(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return false;
  if (isBlockedResurfacingCopy(trimmed)) return false;
  if (isGenericResurfacingCopy(trimmed)) return false;
  if (GENERIC_INSIGHT_RE.test(trimmed)) return false;
  if (/\b(you should|try to|consider|diagnos|therapy|healing journey)\b/i.test(trimmed)) return false;
  return true;
}

/** Assess why a callback is surfacing now — internal scoring with user-facing explanation. */
export function assessResurfacingWhyNow(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingWhyNowVerdict {
  const text = note.text.trim();
  const signals = detectWhyNowSignals(note, entries);
  const primary = signals[0] ?? null;
  let explanation = primary ? explanationForSignal(primary) : null;
  let blockedReason: string | null = null;

  if (explanation && !isValidExplanation(explanation)) {
    blockedReason = "blocked_copy";
    explanation = null;
  }

  if (!explanation && signals.length > 1) {
    for (const signal of signals.slice(1)) {
      const candidate = explanationForSignal(signal);
      if (isValidExplanation(candidate)) {
        explanation = candidate;
        break;
      }
    }
  }

  return {
    noteId: note.id,
    entryId: note.entryId,
    text,
    explanation,
    primaryKind: primary?.kind ?? null,
    signals,
    evidenceBacked: signals.length > 0 && Boolean(explanation),
    blockedReason,
  };
}

export function hasResurfacingWhyNow(note: MemoryNote, entries: JournalEntry[]): boolean {
  return assessResurfacingWhyNow(note, entries).evidenceBacked;
}

export function pickResurfacingWhyNowExplanation(
  note: MemoryNote,
  entries: JournalEntry[],
): string | null {
  return assessResurfacingWhyNow(note, entries).explanation;
}

export function enrichNoteWithWhyNowExplanation(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote {
  const explanation = pickResurfacingWhyNowExplanation(note, entries);
  if (!explanation) return note;
  return { ...note, evidenceReason: explanation };
}

export function collectResurfacingWhyNowCandidates(entries: JournalEntry[]): MemoryNote[] {
  return collectResurfacingConfidenceCandidates(entries);
}

export { formatGapLabel };
