import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { buildContinuityMomentsReport } from "@/lib/patterns/continuity-moments";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export const REVISIT_WORTH_MIN = 58;
export const REVISIT_WORTH_POOL = 5;
export const REVISIT_WORTH_UI = 1;
export const MIN_REVISIT_AGE_DAYS = 12;
export const MIN_CONTRAST_DELTA = 1.2;

export interface RevisitWorthSignal {
  id: string;
  points: number;
}

export interface RevisitWorthEntry {
  entryId: string;
  total: number;
  suppressed: boolean;
  suppressReason?: "recent" | "unrelated" | "similar_only" | "weak";
  signals: RevisitWorthSignal[];
}

export interface RevisitWorthReport {
  entries: RevisitWorthEntry[];
  topEntryIds: string[];
  hasData: boolean;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((sum, v) => sum + v, 0) / values.length) * 10) / 10;
}

function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

function quoteQuality(entry: JournalEntry): number {
  const reflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  const transcript = entry.transcript.trim();
  const snippet = reflection || transcript;
  if (snippet.length < 24) return 0;
  let score = 0;
  if (reflection && reflection.length >= 24) score += 8;
  if (transcript.length >= 40) score += 4;
  if (/\b(decided|named|clearly|for sure|mum|dad|mother|father)\b/i.test(snippet)) score += 4;
  return score;
}

function scoreThenVsNowQuality(
  candidate: JournalEntry,
  sorted: JournalEntry[],
): number {
  const continuity = buildContinuityMomentsReport(sorted, {
    context: "memory",
    callbackLimit: 0,
    landmarkLimit: 0,
  });
  let best = 0;
  for (const comparison of continuity.thenVsNowList ?? []) {
    if (comparison.then.entryId !== candidate.id) continue;
    if (!comparison.then.snippet?.trim() || !comparison.now.snippet?.trim()) continue;
    const boost =
      10 +
      Math.min(comparison.confidence - 60, 12) +
      Math.min(comparison.then.snippet.length, 80) / 20;
    best = Math.max(best, boost);
  }
  return best;
}

function scoreKnowsMeStrength(candidate: JournalEntry, latest: JournalEntry): number {
  const overlap = sharedThemes(candidate, latest);
  if (overlap.length === 0) return 0;

  const intensityDelta = Math.abs(
    candidate.reflection.emotionalIntensity - latest.reflection.emotionalIntensity,
  );
  let score = 0;
  if (intensityDelta >= 2) score += 12;
  else if (intensityDelta >= 1.2) score += 6;

  if (candidate.reflection.mood !== latest.reflection.mood) score += 4;

  const hedgeBefore = /\b(maybe|sort of|kind of|not sure|vague)\b/i.test(candidate.transcript);
  const directNow = /\b(named|decided|clearly|for sure|directly)\b/i.test(latest.transcript);
  if (hedgeBefore && directNow) score += 8;

  return score;
}

function scorePhraseDisappearance(candidate: JournalEntry, sorted: JournalEntry[]): number {
  const today = toDayKey(new Date().toISOString());
  const phrases = buildPhraseMemory(sorted);
  let best = 0;

  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    if (lastOcc.entryId !== candidate.id) continue;
    const gap = daysBetweenKeys(lastOcc.dateKey, today);
    if (gap < 14) continue;
    best = Math.max(best, 8 + Math.min(record.count, 4) + Math.min(gap, 10) / 2);
  }

  return Math.round(best);
}

function scoreCalmerEvolution(candidate: JournalEntry, sorted: JournalEntry[]): number {
  const idx = sorted.findIndex((entry) => entry.id === candidate.id);
  if (idx < 0) return 0;

  let best = 0;
  for (const theme of candidate.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const later = sorted.slice(idx + 1).filter((entry) => hasTheme(entry, themeKey));
    if (later.length < 2) continue;

    const before = candidate.reflection.emotionalIntensity;
    const after = roundAvg(later.map((entry) => entry.reflection.emotionalIntensity));
    if (before - after >= 1.5) {
      best = Math.max(best, 10 + Math.round(before - after) * 3);
    }
  }

  return best;
}

function scoreFollowupAfterRelated(candidate: JournalEntry): number {
  const report = buildRetentionLoopReport();
  let score = 0;

  for (const row of report.revisitsCausingReflections) {
    if (row.entryId === candidate.id) score += 10;
  }

  for (const row of report.notesCausingRevisits) {
    if (row.oldEntryOpens > 0 && row.noteText) {
      const themes = candidate.reflection.recurringThemes.join(" ").toLowerCase();
      if (themes && row.noteText.toLowerCase().includes(themes.slice(0, 12))) {
        score += 6;
      }
    }
  }

  for (const event of report.events) {
    if (event.kind !== "followup_recording_completed") continue;
    if (event.pastEntryId === candidate.id || event.targetEntryId === candidate.id) {
      score += 8;
    }
  }

  return Math.min(score, 22);
}

function scoreRevisitConversion(candidate: JournalEntry): number {
  let score = 0;
  const summary = entryInteractionSummary(candidate.id);
  if ((summary?.viewCount ?? 0) > 1) score += 8;
  if ((summary?.viewCount ?? 0) > 2) score += 4;

  const report = buildRetentionLoopReport();
  for (const row of report.notesCausingRevisits) {
    if (row.oldEntryOpens > 0) {
      const snippet =
        candidate.reflection.exactLanguagePattern?.trim() ||
        candidate.transcript.trim().slice(0, 80);
      if (snippet && row.noteText?.includes(snippet.slice(0, 24))) {
        score += 10;
        break;
      }
    }
  }

  for (const event of report.events) {
    if (event.pastEntryId === candidate.id || event.targetEntryId === candidate.id) {
      if (event.kind === "resurfaced_memory_clicked" || event.kind === "old_entry_opened_from_note") {
        score += 6;
      }
      if (event.kind === "entry_revisited") score += 4;
    }
  }

  return Math.min(score, 24);
}

function scoreEntry(
  candidate: JournalEntry,
  sorted: JournalEntry[],
  latest: JournalEntry,
): RevisitWorthEntry {
  const gap = daysBetweenKeys(toDayKey(candidate.createdAt), toDayKey(latest.createdAt));
  const overlap = sharedThemes(candidate, latest);
  const intensityDelta = Math.abs(
    candidate.reflection.emotionalIntensity - latest.reflection.emotionalIntensity,
  );

  if (candidate.id === latest.id) {
    return {
      entryId: candidate.id,
      total: 0,
      suppressed: true,
      suppressReason: "recent",
      signals: [],
    };
  }

  if (gap < MIN_REVISIT_AGE_DAYS) {
    return {
      entryId: candidate.id,
      total: 0,
      suppressed: true,
      suppressReason: "recent",
      signals: [],
    };
  }

  if (overlap.length === 0 && gap < 21) {
    return {
      entryId: candidate.id,
      total: 0,
      suppressed: true,
      suppressReason: "unrelated",
      signals: [],
    };
  }

  if (
    overlap.length > 0 &&
    intensityDelta < 0.8 &&
    candidate.reflection.mood === latest.reflection.mood
  ) {
    return {
      entryId: candidate.id,
      total: 0,
      suppressed: true,
      suppressReason: "similar_only",
      signals: [],
    };
  }

  const signals: RevisitWorthSignal[] = [];

  if (intensityDelta >= MIN_CONTRAST_DELTA) {
    signals.push({
      id: "emotional_contrast",
      points: 10 + Math.round(intensityDelta * 4),
    });
  }

  const bookmark = getBookmarkForEntry(candidate.id);
  if (bookmark) {
    signals.push({
      id: "bookmark",
      points: bookmark.type === "changed_something" ? 24 : 16,
    });
  }

  const followup = scoreFollowupAfterRelated(candidate);
  if (followup > 0) signals.push({ id: "followup_after_note", points: followup });

  const phraseGone = scorePhraseDisappearance(candidate, sorted);
  if (phraseGone > 0) signals.push({ id: "phrase_disappearance", points: phraseGone });

  const calmer = scoreCalmerEvolution(candidate, sorted);
  if (calmer > 0) signals.push({ id: "calmer_evolution", points: calmer });

  const conversion = scoreRevisitConversion(candidate);
  if (conversion > 0) signals.push({ id: "revisit_conversion", points: conversion });

  const knowsMe = scoreKnowsMeStrength(candidate, latest);
  if (knowsMe > 0) signals.push({ id: "knows_me_strength", points: knowsMe });

  const tvn = scoreThenVsNowQuality(candidate, sorted);
  if (tvn > 0) signals.push({ id: "then_vs_now_quotes", points: tvn });

  const quote = quoteQuality(candidate);
  if (quote > 0) signals.push({ id: "quote_quality", points: quote });

  const total = signals.reduce((sum, signal) => sum + signal.points, 0);

  return {
    entryId: candidate.id,
    total,
    suppressed: total < REVISIT_WORTH_MIN,
    suppressReason: total < REVISIT_WORTH_MIN ? "weak" : undefined,
    signals,
  };
}

function buildWorthMap(entries: JournalEntry[]): Map<string, RevisitWorthEntry> {
  const sorted = sortedEntries(entries);
  if (sorted.length < 2) return new Map();

  const latest = sorted[sorted.length - 1];
  const map = new Map<string, RevisitWorthEntry>();

  for (const entry of sorted.slice(0, -1)) {
    map.set(entry.id, scoreEntry(entry, sorted, latest));
  }

  return map;
}

/** Score every old entry for emotional reopening value — debug and internal ranking. */
export function buildRevisitWorthReport(entries: JournalEntry[]): RevisitWorthReport {
  const map = buildWorthMap(entries);
  const ranked = [...map.values()]
    .filter((row) => !row.suppressed)
    .sort((a, b) => b.total - a.total)
    .slice(0, REVISIT_WORTH_POOL);

  return {
    entries: ranked,
    topEntryIds: ranked.map((row) => row.entryId),
    hasData: ranked.length > 0,
  };
}

export function revisitWorthForEntry(
  entryId: string,
  entries: JournalEntry[],
): RevisitWorthEntry | null {
  return buildWorthMap(entries).get(entryId) ?? null;
}

export function revisitWorthScore(entryId: string, entries: JournalEntry[]): number {
  return revisitWorthForEntry(entryId, entries)?.total ?? 0;
}

export function isRevisitWorthSuppressed(entryId: string, entries: JournalEntry[]): boolean {
  const row = revisitWorthForEntry(entryId, entries);
  if (!row) return true;
  return row.suppressed;
}

export function isWorthRevisitingEntry(entryId: string, entries: JournalEntry[]): boolean {
  const row = revisitWorthForEntry(entryId, entries);
  return Boolean(row && !row.suppressed);
}

function linkedOldEntryId(note: MemoryNote): string | undefined {
  return note.pastEntryId ?? undefined;
}

function noteRankScore(note: MemoryNote, entries: JournalEntry[]): number {
  const hierarchy = scoreMemoryHierarchy(note, entries).total;
  const pastId = linkedOldEntryId(note);
  const worth = pastId ? revisitWorthScore(pastId, entries) : 0;
  return hierarchy + worth * 0.55 + note.confidence * 0.2;
}

/** Rank memory notes so links to emotionally worth-reopening entries surface first. */
export function prioritizeMemoryNotesByRevisitWorth(
  notes: MemoryNote[],
  entries: JournalEntry[],
  limit = REVISIT_WORTH_UI,
): MemoryNote[] {
  const filtered = notes.filter((note) => {
    const pastId = linkedOldEntryId(note);
    if (!pastId) return true;
    return !isRevisitWorthSuppressed(pastId, entries);
  });

  return [...filtered]
    .sort((a, b) => noteRankScore(b, entries) - noteRankScore(a, entries))
    .slice(0, limit);
}

/** Timeline / journal lists — worth-reopening entries first, without changing total count. */
export function orderEntriesForRevisitPrompts(
  entries: JournalEntry[],
  displayLimit = 12,
): JournalEntry[] {
  const worthIds = new Set(buildRevisitWorthReport(entries).topEntryIds);
  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  const worth = sorted.filter((entry) => worthIds.has(entry.id));
  const rest = sorted.filter((entry) => !worthIds.has(entry.id));
  return [...worth, ...rest].slice(0, displayLimit);
}

export function revisitWorthBoostForNote(
  note: MemoryNote,
  entries: JournalEntry[],
): number {
  const pastId = linkedOldEntryId(note);
  if (!pastId || isRevisitWorthSuppressed(pastId, entries)) return 0;
  return Math.round(revisitWorthScore(pastId, entries) * 0.45);
}
