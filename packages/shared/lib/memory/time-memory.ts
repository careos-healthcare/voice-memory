import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type { TimeMemoryContext, TimeMemoryKind, TimeMemoryNote, TimeMemoryReport } from "@/types/time-memory";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const DAY_NAMES = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

const DAY_NAMES_PLURAL = [
  "Sundays",
  "Mondays",
  "Tuesdays",
  "Wednesdays",
  "Thursdays",
  "Fridays",
  "Saturdays",
] as const;

const MIN_ARCHIVE_ENTRIES = 4;
const MIN_DOW_SAMPLES = 2;

export interface TimeMemoryOptions {
  context: TimeMemoryContext;
  entryId?: string;
  limit?: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function dayOfWeek(iso: string): number {
  return new Date(iso).getDay();
}

function monthKey(iso: string): string {
  return toDayKey(iso).slice(0, 7);
}

function hourOf(iso: string): number {
  return new Date(iso).getHours();
}

function timeBucket(hour: number): "morning" | "afternoon" | "evening" | "night" {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

function timeBucketLabel(bucket: ReturnType<typeof timeBucket>): string {
  switch (bucket) {
    case "morning":
      return "Mornings";
    case "afternoon":
      return "Afternoons";
    case "evening":
      return "Evenings";
    case "night":
      return "Nights";
  }
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function countThemes(entries: JournalEntry[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  return counts;
}

function dominantTheme(entries: JournalEntry[]): string | null {
  const counts = countThemes(entries);
  let best: string | null = null;
  let bestCount = 0;
  for (const [theme, count] of counts) {
    if (count > bestCount) {
      best = theme;
      bestCount = count;
    }
  }
  return best;
}

function pushCandidate(
  bucket: TimeMemoryNote[],
  item: Omit<TimeMemoryNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectDayOfWeekPatterns(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const notes: TimeMemoryNote[] = [];
  const overallAvg = roundAvg(sorted.map((e) => e.reflection.emotionalIntensity));
  const recentCutoff = addDaysToKey(toDayKey(new Date().toISOString()), -45);
  const recent = sorted.filter((e) => toDayKey(e.createdAt) >= recentCutoff);

  for (let dow = 0; dow < 7; dow += 1) {
    const dayEntries = recent.filter((e) => dayOfWeek(e.createdAt) === dow);
    if (dayEntries.length < MIN_DOW_SAMPLES) continue;

    const dayAvg = roundAvg(dayEntries.map((e) => e.reflection.emotionalIntensity));
    const theme = dominantTheme(dayEntries);
    const delta = dayAvg - overallAvg;

    if (delta >= 1.2 && theme) {
      pushCandidate(notes, {
        id: `time-dow-heavy-${dow}`,
        kind: "day_of_week",
        text: `${DAY_NAMES_PLURAL[dow]} have carried more ${theme} lately.`,
        strength: 60 + Math.round(delta * 4) + dayEntries.length * 2,
        currentQuote: snippet(dayEntries[dayEntries.length - 1]),
        entryId: dayEntries[dayEntries.length - 1].id,
      });
    } else if (delta <= -1.2 && theme) {
      pushCandidate(notes, {
        id: `time-dow-light-${dow}`,
        kind: "day_of_week",
        text: `${DAY_NAMES_PLURAL[dow]} have sounded lighter lately.`,
        strength: 58 + Math.round(Math.abs(delta) * 4) + dayEntries.length * 2,
        currentQuote: snippet(dayEntries[dayEntries.length - 1]),
        entryId: dayEntries[dayEntries.length - 1].id,
      });
    } else if (theme && dayEntries.length >= 3) {
      pushCandidate(notes, {
        id: `time-dow-theme-${dow}-${theme}`,
        kind: "recurring_day",
        text: `${theme} keeps showing up on ${DAY_NAMES_PLURAL[dow]}.`,
        strength: 58 + dayEntries.length * 3,
        currentQuote: snippet(dayEntries[dayEntries.length - 1]),
        entryId: dayEntries[dayEntries.length - 1].id,
      });
    }
  }

  return notes;
}

function detectTimeOfDayPatterns(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const hours = sorted.map((e) => hourOf(e.createdAt));
  const uniqueBuckets = new Set(hours.map((h) => timeBucket(h)));
  if (uniqueBuckets.size < 2) return [];

  const notes: TimeMemoryNote[] = [];
  const overallAvg = roundAvg(sorted.map((e) => e.reflection.emotionalIntensity));
  const recentCutoff = addDaysToKey(toDayKey(new Date().toISOString()), -30);
  const recent = sorted.filter((e) => toDayKey(e.createdAt) >= recentCutoff);

  for (const bucket of ["morning", "afternoon", "evening", "night"] as const) {
    const bucketEntries = recent.filter((e) => timeBucket(hourOf(e.createdAt)) === bucket);
    if (bucketEntries.length < 2) continue;

    const bucketAvg = roundAvg(bucketEntries.map((e) => e.reflection.emotionalIntensity));
    const theme = dominantTheme(bucketEntries);
    const delta = bucketAvg - overallAvg;

    if (delta >= 1.2 && theme) {
      pushCandidate(notes, {
        id: `time-tod-${bucket}`,
        kind: "time_of_day",
        text: `${timeBucketLabel(bucket)} have carried more ${theme} lately.`,
        strength: 59 + Math.round(delta * 3) + bucketEntries.length * 2,
        currentQuote: snippet(bucketEntries[bucketEntries.length - 1]),
        entryId: bucketEntries[bucketEntries.length - 1].id,
      });
    } else if (bucket === "night" && bucketEntries.length >= 2 && theme) {
      pushCandidate(notes, {
        id: `time-night-${theme}`,
        kind: "time_of_day",
        text: `${theme} tends to come up at night.`,
        strength: 58 + bucketEntries.length * 3,
        currentQuote: snippet(bucketEntries[bucketEntries.length - 1]),
        entryId: bucketEntries[bucketEntries.length - 1].id,
      });
    }
  }

  return notes;
}

function detectMonthlyCompare(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const now = new Date();
  const thisMonth = monthKey(now.toISOString());
  const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 15);
  const lastMonth = monthKey(lastMonthDate.toISOString());

  const thisEntries = sorted.filter((e) => monthKey(e.createdAt) === thisMonth);
  const lastEntries = sorted.filter((e) => monthKey(e.createdAt) === lastMonth);
  if (thisEntries.length < 2 || lastEntries.length < 2) return [];

  const thisAvg = roundAvg(thisEntries.map((e) => e.reflection.emotionalIntensity));
  const lastAvg = roundAvg(lastEntries.map((e) => e.reflection.emotionalIntensity));
  const delta = lastAvg - thisAvg;
  const notes: TimeMemoryNote[] = [];

  if (delta >= 1) {
    pushCandidate(notes, {
      id: `time-month-lighter-${thisMonth}`,
      kind: "monthly_compare",
      text: "This month sounds lighter than the last one.",
      strength: 62 + Math.round(delta * 4),
      pastQuote: snippet(lastEntries[lastEntries.length - 1]),
      currentQuote: snippet(thisEntries[thisEntries.length - 1]),
      pastEntryId: lastEntries[lastEntries.length - 1].id,
      entryId: thisEntries[thisEntries.length - 1].id,
    });
  } else if (delta <= -1) {
    pushCandidate(notes, {
      id: `time-month-heavier-${thisMonth}`,
      kind: "monthly_compare",
      text: "This month sounds heavier than the last one.",
      strength: 60 + Math.round(Math.abs(delta) * 4),
      pastQuote: snippet(lastEntries[lastEntries.length - 1]),
      currentQuote: snippet(thisEntries[thisEntries.length - 1]),
      pastEntryId: lastEntries[lastEntries.length - 1].id,
      entryId: thisEntries[thisEntries.length - 1].id,
    });
  }

  return notes;
}

function detectSeasonalRepeats(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < 8) return [];

  const byMonth = new Map<number, JournalEntry[]>();
  for (const entry of sorted) {
    const m = new Date(entry.createdAt).getMonth();
    const list = byMonth.get(m) ?? [];
    list.push(entry);
    byMonth.set(m, list);
  }

  const nowMonth = new Date().getMonth();
  const thisMonthEntries = byMonth.get(nowMonth) ?? [];
  if (thisMonthEntries.length < 2) return [];

  const theme = dominantTheme(thisMonthEntries);
  if (!theme) return [];

  let priorMonthHits = 0;
  for (const [month, entries] of byMonth) {
    if (month === nowMonth) continue;
    if (entries.some((e) => e.reflection.recurringThemes.some((t) => t.toLowerCase() === theme))) {
      priorMonthHits += 1;
    }
  }

  if (priorMonthHits < 2) return [];

  const notes: TimeMemoryNote[] = [];
  pushCandidate(notes, {
    id: `time-seasonal-${theme}-${nowMonth}`,
    kind: "seasonal_repeat",
    text: `${theme} has come back around this time of year before.`,
    strength: 58 + priorMonthHits * 4 + thisMonthEntries.length * 2,
    currentQuote: snippet(thisMonthEntries[thisMonthEntries.length - 1]),
    entryId: thisMonthEntries[thisMonthEntries.length - 1].id,
  });

  return notes;
}

function detectEndOfWeekThemes(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const lateWeek = sorted.filter((e) => {
    const dow = dayOfWeek(e.createdAt);
    return dow === 0 || dow >= 4;
  });
  const earlyWeek = sorted.filter((e) => {
    const dow = dayOfWeek(e.createdAt);
    return dow >= 1 && dow <= 3;
  });
  if (lateWeek.length < 2 || earlyWeek.length < 2) return [];

  const lateThemes = countThemes(lateWeek);
  const earlyThemes = countThemes(earlyWeek);
  const notes: TimeMemoryNote[] = [];

  for (const [theme, lateCount] of lateThemes) {
    const earlyCount = earlyThemes.get(theme) ?? 0;
    if (lateCount >= 2 && lateCount >= earlyCount + 1) {
      pushCandidate(notes, {
        id: `time-eow-${theme}`,
        kind: "end_of_week",
        text: `${theme.charAt(0).toUpperCase()}${theme.slice(1)} tends to return near the end of the week.`,
        strength: 60 + lateCount * 3,
        currentQuote: snippet(lateWeek[lateWeek.length - 1]),
        entryId: lateWeek[lateWeek.length - 1].id,
      });
    }
  }

  return notes;
}

function detectPeriodShift(sorted: JournalEntry[]): TimeMemoryNote[] {
  if (sorted.length < 6) return [];

  const today = toDayKey(new Date().toISOString());
  const recentStart = addDaysToKey(today, -14);
  const priorStart = addDaysToKey(today, -28);
  const priorEnd = addDaysToKey(today, -15);

  const recent = sorted.filter((e) => toDayKey(e.createdAt) >= recentStart);
  const prior = sorted.filter(
    (e) => toDayKey(e.createdAt) >= priorStart && toDayKey(e.createdAt) <= priorEnd,
  );
  if (recent.length < 2 || prior.length < 2) return [];

  const recentAvg = roundAvg(recent.map((e) => e.reflection.emotionalIntensity));
  const priorAvg = roundAvg(prior.map((e) => e.reflection.emotionalIntensity));
  const delta = priorAvg - recentAvg;
  const notes: TimeMemoryNote[] = [];

  if (delta >= 1.2) {
    pushCandidate(notes, {
      id: "time-period-lighter",
      kind: "period_shift",
      text: "The last couple of weeks sound lighter than the ones before.",
      strength: 60 + Math.round(delta * 4),
      pastQuote: snippet(prior[prior.length - 1]),
      currentQuote: snippet(recent[recent.length - 1]),
      pastEntryId: prior[prior.length - 1].id,
      entryId: recent[recent.length - 1].id,
    });
  } else if (delta <= -1.2) {
    pushCandidate(notes, {
      id: "time-period-heavier",
      kind: "period_shift",
      text: "The last couple of weeks sound heavier than the ones before.",
      strength: 60 + Math.round(Math.abs(delta) * 4),
      pastQuote: snippet(prior[prior.length - 1]),
      currentQuote: snippet(recent[recent.length - 1]),
      pastEntryId: prior[prior.length - 1].id,
      entryId: recent[recent.length - 1].id,
    });
  }

  return notes;
}

function detectEntryTimePatterns(
  current: JournalEntry,
  prior: JournalEntry[],
): TimeMemoryNote[] {
  const notes: TimeMemoryNote[] = [];
  const dow = dayOfWeek(current.createdAt);
  const dayName = DAY_NAMES[dow];
  const currentKey = toDayKey(current.createdAt);

  const lastWeekKey = addDaysToKey(currentKey, -7);
  const lastWeekEntry = prior.find((e) => toDayKey(e.createdAt) === lastWeekKey);
  if (lastWeekEntry) {
    const shared = sharedThemes(current, lastWeekEntry);
    if (shared.length > 0 || lastWeekEntry.reflection.mood === current.reflection.mood) {
      pushCandidate(notes, {
        id: `time-same-week-${current.id}`,
        kind: "same_day_last_week",
        text: `This feels similar to last ${dayName}.`,
        strength: 62 + shared.length * 4,
        pastQuote: snippet(lastWeekEntry),
        currentQuote: snippet(current),
        pastEntryId: lastWeekEntry.id,
        entryId: current.id,
      });
    }
  }

  const lastMonthKey = addDaysToKey(currentKey, -28);
  const lastMonthEntry = prior.find((e) => {
    const gap = Math.abs(daysBetweenKeys(toDayKey(e.createdAt), lastMonthKey));
    return gap <= 3;
  });
  if (lastMonthEntry) {
    const shared = sharedThemes(current, lastMonthEntry);
    if (shared.length > 0) {
      pushCandidate(notes, {
        id: `time-same-month-${current.id}`,
        kind: "same_day_last_month",
        text: "This feels similar to around this time last month.",
        strength: 60 + shared.length * 3,
        pastQuote: snippet(lastMonthEntry),
        currentQuote: snippet(current),
        pastEntryId: lastMonthEntry.id,
        entryId: current.id,
      });
    }
  }

  const sameDowPrior = prior.filter((e) => dayOfWeek(e.createdAt) === dow);
  if (sameDowPrior.length >= 1 && !lastWeekEntry) {
    const lastSameDow = sameDowPrior[sameDowPrior.length - 1];
    const shared = sharedThemes(current, lastSameDow);
    if (shared.length > 0) {
      pushCandidate(notes, {
        id: `time-same-dow-${dow}-${current.id}`,
        kind: "recurring_day",
        text: `This feels similar to last ${dayName}.`,
        strength: 59 + shared.length * 3,
        pastQuote: snippet(lastSameDow),
        currentQuote: snippet(current),
        pastEntryId: lastSameDow.id,
        entryId: current.id,
      });
    }
  }

  const sameDowAll = [...prior, current].filter((e) => dayOfWeek(e.createdAt) === dow);
  if (sameDowAll.length >= 3) {
    const dayAvg = roundAvg(sameDowAll.map((e) => e.reflection.emotionalIntensity));
    const otherAvg = roundAvg(
      prior.filter((e) => dayOfWeek(e.createdAt) !== dow).map((e) => e.reflection.emotionalIntensity),
    );
    if (otherAvg - dayAvg >= 1.2) {
      pushCandidate(notes, {
        id: `time-entry-dow-light-${dow}-${current.id}`,
        kind: "day_of_week",
        text: `${DAY_NAMES_PLURAL[dow]} have sounded lighter for you.`,
        strength: 58 + sameDowAll.length * 2,
        currentQuote: snippet(current),
        entryId: current.id,
      });
    }
  }

  return notes;
}

const CONTEXT_KIND_PRIORITY: Record<TimeMemoryContext, TimeMemoryKind[]> = {
  homepage: ["monthly_compare", "day_of_week", "end_of_week", "period_shift", "recurring_day"],
  timeline: ["day_of_week", "period_shift", "end_of_week", "time_of_day", "recurring_day", "monthly_compare"],
  monthly: ["monthly_compare", "seasonal_repeat", "period_shift", "day_of_week", "end_of_week"],
  entry: ["same_day_last_week", "recurring_day", "same_day_last_month", "day_of_week"],
};

function dedupeNotes(notes: TimeMemoryNote[]): TimeMemoryNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.text.slice(0, 36)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(notes: TimeMemoryNote[], context: TimeMemoryContext, limit: number): TimeMemoryNote[] {
  const priority = CONTEXT_KIND_PRIORITY[context];
  const sorted = dedupeNotes(notes);
  const picked: TimeMemoryNote[] = [];
  const usedKinds = new Set<TimeMemoryKind>();

  for (const kind of priority) {
    if (picked.length >= limit) break;
    const match = sorted.find((n) => n.kind === kind && !usedKinds.has(n.kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  for (const note of sorted) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === note.id)) continue;
    picked.push(note);
  }

  return picked.slice(0, limit);
}

function collectArchiveCandidates(sorted: JournalEntry[]): TimeMemoryNote[] {
  return [
    ...detectDayOfWeekPatterns(sorted),
    ...detectTimeOfDayPatterns(sorted),
    ...detectMonthlyCompare(sorted),
    ...detectSeasonalRepeats(sorted),
    ...detectEndOfWeekThemes(sorted),
    ...detectPeriodShift(sorted),
  ];
}

/** Detect quiet time-based familiarity across reflections. */
export function buildTimeMemoryReport(
  entries: JournalEntry[],
  options: TimeMemoryOptions,
): TimeMemoryReport {
  const limit = options.limit ?? (options.context === "entry" || options.context === "homepage" ? 1 : 2);
  const sorted = sortedEntries(entries);

  if (sorted.length < 2) {
    return { notes: [], hasData: false };
  }

  let candidates: TimeMemoryNote[] = [];

  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx > 0) {
      candidates = detectEntryTimePatterns(sorted[idx], sorted.slice(0, idx));
    }
  } else {
    candidates = collectArchiveCandidates(sorted);
    if (options.context === "entry") {
      const latest = sorted[sorted.length - 1];
      candidates.push(...detectEntryTimePatterns(latest, sorted.slice(0, -1)));
    }
  }

  const notes = pickForContext(candidates, options.context, limit);
  return { notes, hasData: notes.length > 0 };
}

export function timeMemoryToNotes(notes: TimeMemoryNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "changed" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
  }));
}

export function homepageTimeMemoryNotes(entries: JournalEntry[]): MemoryNote[] {
  return applyMemoryHierarchy(
    timeMemoryToNotes(buildTimeMemoryReport(entries, { context: "homepage", limit: 1 }).notes),
    entries,
    1,
  );
}

export function timelineTimeMemoryNotes(entries: JournalEntry[]): MemoryNote[] {
  return applyMemoryHierarchy(
    timeMemoryToNotes(buildTimeMemoryReport(entries, { context: "timeline", limit: 2 }).notes),
    entries,
    1,
  );
}

export function monthlyTimeMemoryNotes(entries: JournalEntry[]): MemoryNote[] {
  return applyMemoryHierarchy(
    timeMemoryToNotes(buildTimeMemoryReport(entries, { context: "monthly", limit: 2 }).notes),
    entries,
    1,
  );
}

export function entryTimeMemoryNotes(entries: JournalEntry[], entryId: string): MemoryNote[] {
  return applyMemoryHierarchy(
    timeMemoryToNotes(
      buildTimeMemoryReport(entries, { context: "entry", entryId, limit: 1 }).notes,
    ),
    entries,
    1,
  );
}
