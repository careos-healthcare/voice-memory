import type { ChangeMomentKind, ChangeMomentNote } from "@/types/change-moments";
import type { FamiliarityResurfacingKind, FamiliarityResurfacingNote } from "@/types/familiarity-resurfacing";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { ResurfacingKind, ResurfacingNote } from "@/types/resurfacing";
import type { RevisitationKind, RevisitationNote } from "@/types/revisitation";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { weightResurfacingNote, weightRevisitationKind } from "@/lib/memory/emotional-weight";
import {
  isRevisitWorthSuppressed,
  revisitWorthBoostForNote,
} from "@/lib/refinement/revisit-worth";

const FATIGUE_KEY = "voicememory_resurfacing_fatigue";
const MAX_FATIGUE_RECORDS = 48;
const MS_PER_DAY = 1000 * 60 * 60 * 24;

export const RESURFACING_MIN_WEIGHT = 62;
export const RESURFACING_LONG_SILENCE_DAYS = 21;
export const RESURFACING_MIN_ABSENCE_DAYS = 10;

export type ResurfacingSurface =
  | "homepage"
  | "entry"
  | "timeline"
  | "monthly"
  | "memory";

export type ResurfacingFatigueCategory =
  | "change_moment"
  | "emotional_contrast"
  | "first_calmer"
  | "loop_long_silence"
  | "loop_return"
  | "person_return"
  | "phrase_return"
  | "topic_return"
  | "familiarity_reconnect"
  | "revisitation"
  | "tone_shift";

export interface ResurfacingFatigueRecord {
  category: ResurfacingFatigueCategory;
  textKey: string;
  noteId: string;
  surface: ResurfacingSurface;
  shownAt: number;
}

export interface ResurfacingCandidate {
  note: MemoryNote;
  category: ResurfacingFatigueCategory;
  emotionalWeight: number;
  gapDays?: number;
  priority: number;
}

export interface ApplyResurfacingRarityOptions {
  surface: ResurfacingSurface;
  limit?: number;
  record?: boolean;
  entries?: JournalEntry[];
}

const CATEGORY_COOLDOWN_DAYS: Partial<Record<ResurfacingFatigueCategory, number>> = {
  change_moment: 4,
  emotional_contrast: 5,
  first_calmer: 6,
  loop_long_silence: 7,
  loop_return: 5,
  topic_return: 7,
  phrase_return: 8,
  person_return: 6,
  familiarity_reconnect: 5,
  revisitation: 6,
  tone_shift: 5,
};

const CATEGORY_PRIORITY: Record<ResurfacingFatigueCategory, number> = {
  change_moment: 100,
  emotional_contrast: 92,
  first_calmer: 88,
  loop_long_silence: 84,
  loop_return: 70,
  familiarity_reconnect: 68,
  tone_shift: 62,
  person_return: 58,
  revisitation: 54,
  phrase_return: 90,
  topic_return: 38,
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function readFatigueRecords(): ResurfacingFatigueRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(FATIGUE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ResurfacingFatigueRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeFatigueRecords(records: ResurfacingFatigueRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(FATIGUE_KEY, JSON.stringify(records.slice(-MAX_FATIGUE_RECORDS)));
}

export function gapDaysBetweenEntries(
  entries: { id: string; createdAt: string }[],
  pastEntryId?: string,
  entryId?: string,
): number {
  if (!pastEntryId || !entryId) return 0;
  const past = entries.find((entry) => entry.id === pastEntryId);
  const current = entries.find((entry) => entry.id === entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

export function clearResurfacingFatigue(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(FATIGUE_KEY);
}

export function getResurfacingFatigueRecords(): ResurfacingFatigueRecord[] {
  return readFatigueRecords();
}

function daysSince(timestamp: number): number {
  return (Date.now() - timestamp) / MS_PER_DAY;
}

function isSimilarTextFatigued(text: string, withinDays = 7): boolean {
  const key = textKey(text);
  if (!key) return false;
  return readFatigueRecords().some(
    (record) => record.textKey === key && daysSince(record.shownAt) < withinDays,
  );
}

function isCategoryFatigued(category: ResurfacingFatigueCategory): boolean {
  const cooldown = CATEGORY_COOLDOWN_DAYS[category] ?? 5;
  return readFatigueRecords().some(
    (record) => record.category === category && daysSince(record.shownAt) < cooldown,
  );
}

function isNoteIdFatigued(noteId: string, withinDays = 14): boolean {
  return readFatigueRecords().some(
    (record) => record.noteId === noteId && daysSince(record.shownAt) < withinDays,
  );
}

export function recordResurfacingShown(
  notes: MemoryNote[],
  surface: ResurfacingSurface,
  categoryOf: (note: MemoryNote) => ResurfacingFatigueCategory,
): void {
  if (!isBrowser() || notes.length === 0) return;

  const existing = readFatigueRecords();
  const now = Date.now();
  const additions = notes.map((note) => ({
    category: categoryOf(note),
    textKey: textKey(note.text),
    noteId: note.id,
    surface,
    shownAt: now,
  }));

  writeFatigueRecords([...existing, ...additions]);
}

function hasEnoughTimePassed(candidate: ResurfacingCandidate): boolean {
  const gap = candidate.gapDays ?? 0;
  switch (candidate.category) {
    case "loop_long_silence":
      return gap >= RESURFACING_LONG_SILENCE_DAYS;
    case "loop_return":
      return gap >= RESURFACING_MIN_ABSENCE_DAYS;
    case "topic_return":
    case "phrase_return":
      return gap >= RESURFACING_LONG_SILENCE_DAYS;
    case "person_return":
      return gap >= RESURFACING_MIN_ABSENCE_DAYS;
    case "revisitation":
      return gap >= 14;
    default:
      return gap >= RESURFACING_MIN_ABSENCE_DAYS || gap === 0;
  }
}

function isEmotionallyMeaningful(candidate: ResurfacingCandidate): boolean {
  if (candidate.emotionalWeight < RESURFACING_MIN_WEIGHT) return false;

  if (
    candidate.category === "topic_return" ||
    candidate.category === "phrase_return"
  ) {
    return candidate.emotionalWeight >= 66 && (candidate.gapDays ?? 0) >= RESURFACING_LONG_SILENCE_DAYS;
  }

  if (candidate.category === "revisitation") {
    return candidate.emotionalWeight >= 64;
  }

  if (candidate.category === "tone_shift") {
    return candidate.emotionalWeight >= 65;
  }

  return true;
}

function isSuppressedCategory(category: ResurfacingFatigueCategory): boolean {
  return category === "phrase_return" && isCategoryFatigued("phrase_return");
}

export function shouldShowResurfacingCandidate(candidate: ResurfacingCandidate): boolean {
  if (!isEmotionallyMeaningful(candidate)) return false;
  if (!hasEnoughTimePassed(candidate)) return false;
  if (isSuppressedCategory(candidate.category)) return false;
  if (isCategoryFatigued(candidate.category)) return false;
  if (isSimilarTextFatigued(candidate.note.text)) return false;
  if (isNoteIdFatigued(candidate.note.id)) return false;
  return true;
}

function scoreCandidate(
  candidate: ResurfacingCandidate,
  entries?: JournalEntry[],
): number {
  let score = candidate.emotionalWeight + candidate.priority;
  const gap = candidate.gapDays ?? 0;

  if (candidate.category === "loop_long_silence" && gap >= RESURFACING_LONG_SILENCE_DAYS) {
    score += 12;
  }
  if (candidate.category === "first_calmer") score += 10;
  if (candidate.category === "emotional_contrast") score += 8;
  if (candidate.category === "change_moment") score += 14;
  if (gap >= RESURFACING_LONG_SILENCE_DAYS) score += 6;

  if (candidate.category === "phrase_return") score -= 12;
  if (candidate.category === "topic_return") score -= 8;
  if (candidate.category === "revisitation" && candidate.emotionalWeight < 66) score -= 10;

  if (entries?.length) {
    const pastId = candidate.note.pastEntryId;
    if (pastId && isRevisitWorthSuppressed(pastId, entries)) return -9999;
    score += revisitWorthBoostForNote(candidate.note, entries);
  }

  return score;
}

export function applyResurfacingRarity(
  candidates: ResurfacingCandidate[],
  options: ApplyResurfacingRarityOptions,
): MemoryNote[] {
  const limit = options.limit ?? 1;

  const eligible = candidates
    .filter(shouldShowResurfacingCandidate)
    .filter(
      (candidate) =>
        !options.entries?.length ||
        !candidate.note.pastEntryId ||
        !isRevisitWorthSuppressed(candidate.note.pastEntryId, options.entries),
    )
    .sort(
      (a, b) => scoreCandidate(b, options.entries) - scoreCandidate(a, options.entries),
    );

  const picked: ResurfacingCandidate[] = [];
  const usedCategories = new Set<ResurfacingFatigueCategory>();
  const usedText = new Set<string>();

  for (const candidate of eligible) {
    if (picked.length >= limit) break;
    const key = textKey(candidate.note.text);
    if (usedCategories.has(candidate.category) || usedText.has(key)) continue;
    picked.push(candidate);
    usedCategories.add(candidate.category);
    usedText.add(key);
  }

  const notes = picked.map((c) => c.note);

  if (options.record !== false && notes.length > 0) {
    recordResurfacingShown(notes, options.surface, (note) => {
      const match = picked.find((p) => p.note.id === note.id);
      return match?.category ?? "topic_return";
    });
  }

  return notes;
}

function baseCandidate(
  note: MemoryNote,
  category: ResurfacingFatigueCategory,
  emotionalWeight: number,
  gapDays?: number,
): ResurfacingCandidate {
  return {
    note,
    category,
    emotionalWeight,
    gapDays,
    priority: CATEGORY_PRIORITY[category],
  };
}

export function candidateFromResurfacingNote(
  note: ResurfacingNote,
  memoryNote: MemoryNote,
  gapDays?: number,
): ResurfacingCandidate {
  const gap = gapDays ?? 0;
  let category: ResurfacingFatigueCategory = "topic_return";

  switch (note.kind) {
    case "loop_return":
      category = gap >= RESURFACING_LONG_SILENCE_DAYS ? "loop_long_silence" : "loop_return";
      break;
    case "calmer_return":
      category = "first_calmer";
      break;
    case "heavier_return":
    case "direct_return":
      category = "emotional_contrast";
      break;
    case "person_silence":
      category = "person_return";
      break;
    case "phrase_return":
      category = "phrase_return";
      break;
    case "vague_return":
      category = "tone_shift";
      break;
    case "topic_silence":
      category = "topic_return";
      break;
  }

  return baseCandidate(
    memoryNote,
    category,
    weightResurfacingNote(note.strength, {
      gapDays: gap,
      isLoop: category === "loop_long_silence" || category === "loop_return",
      isCalmer: category === "first_calmer",
      isContrast: category === "emotional_contrast",
      isDirect: note.kind === "direct_return",
    }),
    gap,
  );
}

export function candidateFromFamiliarityResurfacingNote(
  note: FamiliarityResurfacingNote,
  memoryNote: MemoryNote,
  gapDays?: number,
): ResurfacingCandidate {
  let category: ResurfacingFatigueCategory = "familiarity_reconnect";

  switch (note.kind) {
    case "sound_different":
    case "emotionally_opposite":
    case "before_major_shift":
    case "monthly_contrast":
      category = "emotional_contrast";
      break;
    case "first_calmer_topic":
      category = "first_calmer";
      break;
    case "earlier_loop":
      category = gapDays && gapDays >= RESURFACING_LONG_SILENCE_DAYS
        ? "loop_long_silence"
        : "loop_return";
      break;
    case "before_direct_naming":
      category = "emotional_contrast";
      break;
    case "emotionally_similar":
      category = "tone_shift";
      break;
  }

  const weight =
    note.kind === "emotionally_similar"
      ? weightResurfacingNote(note.strength - 8, { gapDays: gapDays ?? 0 })
      : weightResurfacingNote(note.strength, {
          gapDays: gapDays ?? 0,
          isLoop: note.kind === "earlier_loop",
          isCalmer: note.kind === "first_calmer_topic",
          isContrast:
            note.kind === "sound_different" ||
            note.kind === "emotionally_opposite" ||
            note.kind === "before_major_shift" ||
            note.kind === "monthly_contrast" ||
            note.kind === "before_direct_naming",
          isDirect: note.kind === "before_direct_naming",
        });

  return baseCandidate(memoryNote, category, weight, gapDays);
}

export function candidateFromRevisitationNote(
  note: RevisitationNote,
  memoryNote: MemoryNote,
  gapDays?: number,
): ResurfacingCandidate {
  let category: ResurfacingFatigueCategory = "revisitation";
  let weight = weightRevisitationKind(note.kind, note.strength, gapDays ?? 0);

  switch (note.kind) {
    case "loop_return":
      category =
        gapDays && gapDays >= RESURFACING_LONG_SILENCE_DAYS
          ? "loop_long_silence"
          : "loop_return";
      weight = weightResurfacingNote(weight, {
        gapDays: gapDays ?? 0,
        isLoop: true,
      });
      break;
    case "reads_differently":
      category = "emotional_contrast";
      weight = weightResurfacingNote(weight, {
        gapDays: gapDays ?? 0,
        isContrast: true,
      });
      break;
    case "related_older":
    case "worth_revisit":
    case "first_topic":
      weight -= 4;
      break;
    case "before_quieter":
      category = "first_calmer";
      weight = weightResurfacingNote(weight, { gapDays: gapDays ?? 0, isCalmer: true });
      break;
  }

  return baseCandidate(memoryNote, category, weight, gapDays);
}

export function candidateFromChangeMomentNote(
  note: ChangeMomentNote,
  memoryNote: MemoryNote,
  gapDays?: number,
): ResurfacingCandidate {
  return baseCandidate(
    memoryNote,
    "change_moment",
    weightResurfacingNote(note.strength, {
      gapDays: gapDays ?? 0,
      isContrast: true,
      isCalmer:
        note.kind === "calmer_return" ||
        note.kind === "less_charged" ||
        note.kind === "recovery_after_topic",
      isDirect: note.kind === "less_hedging" || note.kind === "more_direct",
      isLoop: note.kind === "shorter_spiral" || note.kind === "concern_absent",
    }),
    gapDays,
  );
}

export function categoryForMemoryNote(note: MemoryNote): ResurfacingFatigueCategory {
  if (note.id.startsWith("change-")) return "change_moment";
  if (note.id.includes("fam-resurface")) return "familiarity_reconnect";
  if (note.id.includes("resurface-loop")) return "loop_long_silence";
  if (note.id.includes("resurface-calmer")) return "first_calmer";
  if (note.id.includes("resurface-heavier") || note.id.includes("resurface-direct")) {
    return "emotional_contrast";
  }
  if (note.id.includes("revisit-")) return "revisitation";
  if (note.id.includes("resurface-phrase")) return "phrase_return";
  if (note.id.includes("resurface-person")) return "person_return";
  return "topic_return";
}

export function applyRarityToMemoryNotes(
  notes: MemoryNote[],
  surface: ResurfacingSurface,
  limit = 1,
  category: ResurfacingFatigueCategory = "topic_return",
): MemoryNote[] {
  return applyResurfacingRarity(
    notes.map((note) => baseCandidate(note, category, note.confidence)),
    { surface, limit, record: true },
  );
}

/** Map resurfacing kind to fatigue category without a full domain note. */
export function fatigueCategoryForResurfacingKind(kind: ResurfacingKind): ResurfacingFatigueCategory {
  switch (kind) {
    case "loop_return":
      return "loop_return";
    case "calmer_return":
      return "first_calmer";
    case "heavier_return":
    case "direct_return":
      return "emotional_contrast";
    case "person_silence":
      return "person_return";
    case "phrase_return":
      return "phrase_return";
    case "vague_return":
      return "tone_shift";
    case "topic_silence":
      return "topic_return";
  }
}

export function fatigueCategoryForFamiliarityResurfacingKind(
  kind: FamiliarityResurfacingKind,
): ResurfacingFatigueCategory {
  switch (kind) {
    case "sound_different":
    case "emotionally_opposite":
    case "before_major_shift":
    case "monthly_contrast":
    case "before_direct_naming":
      return "emotional_contrast";
    case "first_calmer_topic":
      return "first_calmer";
    case "earlier_loop":
      return "loop_long_silence";
    case "emotionally_similar":
      return "tone_shift";
  }
}

export function fatigueCategoryForRevisitationKind(
  kind: RevisitationKind,
): ResurfacingFatigueCategory {
  switch (kind) {
    case "loop_return":
      return "loop_long_silence";
    case "reads_differently":
      return "emotional_contrast";
    case "before_quieter":
      return "first_calmer";
    default:
      return "revisitation";
  }
}

export function fatigueCategoryForChangeMomentKind(
  kind: ChangeMomentKind,
): ResurfacingFatigueCategory {
  if (
    kind === "less_hedging" ||
    kind === "more_direct" ||
    kind === "you_sound_different" ||
    kind === "recovery_after_topic"
  ) {
    return "change_moment";
  }
  if (kind === "calmer_return" || kind === "less_charged") return "first_calmer";
  if (kind === "shorter_spiral" || kind === "concern_absent") return "loop_long_silence";
  return "emotional_contrast";
}
