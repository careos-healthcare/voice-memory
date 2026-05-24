import { addDaysToKey, startOfWeekKey, toDayKey, todayKey } from "@/lib/dates";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ReflectiveRoundup,
  ReflectiveRoundupLine,
  ReflectiveRoundupSignal,
  RoundupIndexItem,
  RoundupListReport,
  RoundupPeriod,
  RoundupPeriodKind,
} from "@/types/reflective-roundup";

const MAX_LINES = 5;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const CERTAINTY_RE =
  /\b(i know|i will|definitely|clearly|for sure|decided|wrote down|named)\b/gi;
const UNFINISHED_RE =
  /\b(still|unfinished|haven't|didn't|not yet|keep putting off|avoiding|unclear|unsure)\b/gi;

interface LineCandidate {
  text: string;
  entryIds: string[];
  signal: ReflectiveRoundupSignal;
  score: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entriesInRange(
  entries: JournalEntry[],
  startDayKey: string,
  endDayKey: string,
): JournalEntry[] {
  return sortedEntries(entries).filter((entry) => {
    const key = toDayKey(entry.createdAt);
    return key >= startDayKey && key <= endDayKey;
  });
}

function formatRangeLabel(startKey: string, endKey: string): string {
  const [y1, m1, d1] = startKey.split("-").map(Number);
  const [y2, m2, d2] = endKey.split("-").map(Number);
  const start = new Date(y1, m1 - 1, d1);
  const end = new Date(y2, m2 - 1, d2);
  const fmt = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" });
  if (startKey === endKey) return fmt.format(start);
  return `${fmt.format(start)} – ${fmt.format(end)}`;
}

function monthLabelFromKey(monthKey: string): string {
  const [y, m] = monthKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(
    new Date(y, m - 1, 1),
  );
}

function dayName(dayKey: string): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(new Date(y, m - 1, d));
}

function capitalize(text: string): string {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.tensionOrContradiction,
    entry.reflection.avoidedOrVagueArea,
    ...(entry.reflection.patternObservations ?? []),
  ]
    .filter(Boolean)
    .join("\n");
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function themeCounts(entries: JournalEntry[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.trim().toLowerCase();
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  return counts;
}

function dominantMood(entries: JournalEntry[]): string | null {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    const mood = entry.reflection.mood.trim().toLowerCase();
    if (!mood) continue;
    counts.set(mood, (counts.get(mood) ?? 0) + 1);
  }
  const top = [...counts.entries()].sort((a, b) => b[1] - a[1])[0];
  return top?.[0] ?? null;
}

function splitByMidpoint(entries: JournalEntry[]): {
  first: JournalEntry[];
  second: JournalEntry[];
  midpointDayKey: string;
} {
  if (entries.length === 0) {
    return { first: [], second: [], midpointDayKey: todayKey() };
  }
  const midpointIndex = Math.ceil(entries.length / 2);
  const first = entries.slice(0, midpointIndex);
  const second = entries.slice(midpointIndex);
  const midpointDayKey = second[0]
    ? toDayKey(second[0].createdAt)
    : toDayKey(first[first.length - 1]?.createdAt ?? new Date().toISOString());
  return { first, second, midpointDayKey };
}

function periodScopeWord(kind: RoundupPeriodKind): string {
  if (kind === "monthly") return "month";
  if (kind === "custom") return "period";
  return "week";
}

function detectReturned(
  entries: JournalEntry[],
  kind: RoundupPeriodKind,
): LineCandidate | null {
  const { first, second } = splitByMidpoint(entries);
  const allCounts = themeCounts(entries);
  const secondCounts = themeCounts(second);

  const ranked = [...allCounts.entries()]
    .filter(([, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1]);

  for (const [theme, count] of ranked) {
    const inFirst = (themeCounts(first).get(theme) ?? 0) > 0;
    const inSecond = (secondCounts.get(theme) ?? 0) > 0;
    if (!inFirst && !inSecond) continue;

    const entryIds = entries
      .filter((entry) =>
        entry.reflection.recurringThemes.some((row) => row.trim().toLowerCase() === theme),
      )
      .slice(-3)
      .map((entry) => entry.id);

    if (inFirst && inSecond) {
      return {
        text: `You kept returning to ${theme}.`,
        entryIds,
        signal: "returned",
        score: 68 + count * 4,
      };
    }

    if (inSecond && (secondCounts.get(theme) ?? 0) >= 2) {
      return {
        text: `You kept returning to ${theme}.`,
        entryIds,
        signal: "returned",
        score: 62 + count * 3,
      };
    }
  }

  if (kind === "monthly" && ranked.length > 0) {
    const [theme, count] = ranked[0];
    return {
      text: `You kept returning to ${theme}.`,
      entryIds: entries.slice(-2).map((entry) => entry.id),
      signal: "returned",
      score: 58 + count * 2,
    };
  }

  return null;
}

function detectFaded(entries: JournalEntry[]): LineCandidate | null {
  const { first, second, midpointDayKey } = splitByMidpoint(entries);
  if (first.length === 0 || second.length === 0) return null;

  const firstCounts = themeCounts(first);
  const secondCounts = themeCounts(second);

  const faded = [...firstCounts.entries()]
    .filter(([theme, count]) => count >= 2 && (secondCounts.get(theme) ?? 0) === 0)
    .sort((a, b) => b[1] - a[1])[0];

  if (!faded) return null;

  const [theme] = faded;
  const entryIds = first
    .filter((entry) =>
      entry.reflection.recurringThemes.some((row) => row.trim().toLowerCase() === theme),
    )
    .slice(-2)
    .map((entry) => entry.id);

  return {
    text: `${capitalize(theme)} appeared less after ${dayName(midpointDayKey)}.`,
    entryIds,
    signal: "faded",
    score: 70,
  };
}

function detectToneAndClarity(entries: JournalEntry[]): LineCandidate[] {
  const { first, second } = splitByMidpoint(entries);
  if (first.length === 0 || second.length === 0) return [];

  const firstText = first.map(entryText).join("\n");
  const secondText = second.map(entryText).join("\n");

  const hedgeFirst = countMatches(firstText, HEDGE_RE);
  const hedgeSecond = countMatches(secondText, HEDGE_RE);
  const certaintyFirst = countMatches(firstText, CERTAINTY_RE);
  const certaintySecond = countMatches(secondText, CERTAINTY_RE);

  const intensityFirst = roundAvg(first.map((entry) => entry.reflection.emotionalIntensity));
  const intensitySecond = roundAvg(second.map((entry) => entry.reflection.emotionalIntensity));

  const lines: LineCandidate[] = [];
  const entryIds = second.slice(-2).map((entry) => entry.id);

  if (certaintySecond > certaintyFirst + 1 || (hedgeFirst > 0 && hedgeSecond < hedgeFirst - 1)) {
    lines.push({
      text: "You sounded more certain near the end.",
      entryIds,
      signal: "clearer",
      score: 72,
    });
  }

  if (intensitySecond + 1.2 < intensityFirst) {
    lines.push({
      text: "You sounded calmer near the end.",
      entryIds,
      signal: "tone_shift",
      score: 66,
    });
  } else if (intensitySecond > intensityFirst + 1.2) {
    lines.push({
      text: "You sounded more charged near the end.",
      entryIds,
      signal: "tone_shift",
      score: 64,
    });
  }

  return lines;
}

function detectUnfinished(entries: JournalEntry[]): LineCandidate | null {
  const recent = entries.slice(-3);
  for (const entry of [...recent].reverse()) {
    const open =
      entry.reflection.tensionOrContradiction?.trim() ||
      entry.reflection.avoidedOrVagueArea?.trim() ||
      entry.reflection.nextSmallAction?.trim();

    if (!open) continue;

    const body = entryText(entry);
    if (!UNFINISHED_RE.test(body) && !open) continue;

    if (entry.reflection.tensionOrContradiction || entry.reflection.avoidedOrVagueArea) {
      return {
        text: "One thought stayed unfinished.",
        entryIds: [entry.id],
        signal: "unfinished",
        score: 74,
      };
    }
  }

  const last = entries[entries.length - 1];
  if (!last) return null;

  if (last.reflection.tensionOrContradiction?.trim() || last.reflection.avoidedOrVagueArea?.trim()) {
    return {
      text: "One thought stayed unfinished.",
      entryIds: [last.id],
      signal: "unfinished",
      score: 68,
    };
  }

  return null;
}

function detectWeight(entries: JournalEntry[], kind: RoundupPeriodKind): LineCandidate | null {
  const { first, second } = splitByMidpoint(entries);
  if (first.length === 0 || second.length === 0) return null;

  const delta =
    roundAvg(second.map((entry) => entry.reflection.emotionalIntensity)) -
    roundAvg(first.map((entry) => entry.reflection.emotionalIntensity));

  const entryIds = second.slice(-2).map((entry) => entry.id);
  const scope = periodScopeWord(kind);

  if (delta >= 1.5) {
    return {
      text: `The ${scope} felt heavier toward the end.`,
      entryIds,
      signal: "heavier",
      score: 63,
    };
  }

  if (delta <= -1.5) {
    return {
      text: `The ${scope} felt lighter toward the end.`,
      entryIds,
      signal: "lighter",
      score: 61,
    };
  }

  return null;
}

function detectRevisited(
  period: RoundupPeriod,
  entries: JournalEntry[],
): LineCandidate | null {
  const events = readRetentionLoopEvents().filter((event) => {
    const key = toDayKey(event.at);
    return key >= period.startDayKey && key <= period.endDayKey;
  });

  const revisits = events.filter(
    (event) => event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note",
  );

  if (revisits.length === 0) return null;

  const entryIds = [
    ...new Set(
      revisits
        .map((event) => event.targetEntryId ?? event.pastEntryId ?? event.entryId)
        .filter(Boolean) as string[],
    ),
  ].slice(0, 3);

  const text =
    revisits.length === 1
      ? "You came back to an older entry."
      : "You kept revisiting what you had already written.";

  return {
    text,
    entryIds: entryIds.length > 0 ? entryIds : entries.slice(-1).map((entry) => entry.id),
    signal: "revisited",
    score: 65 + Math.min(revisits.length, 4) * 3,
  };
}

function detectCarriedDifferently(
  entries: JournalEntry[],
  kind: RoundupPeriodKind,
): LineCandidate | null {
  const { first, second } = splitByMidpoint(entries);
  if (first.length === 0 || second.length === 0) return null;

  const moodFirst = dominantMood(first);
  const moodSecond = dominantMood(second);

  if (moodFirst && moodSecond && moodFirst !== moodSecond) {
    return {
      text:
        kind === "monthly"
          ? "This month reads differently from the beginning."
          : "This period reads differently from the beginning.",
      entryIds: [...first.slice(-1), ...second.slice(-1)].map((entry) => entry.id),
      signal: "carried_differently",
      score: 67,
    };
  }

  if (kind === "monthly" && entries.length >= 4) {
    const earlySnippet =
      first[0]?.reflection.exactLanguagePattern?.trim() ||
      first[0]?.reflection.concreteObservation?.trim();
    const lateSnippet =
      second[second.length - 1]?.reflection.exactLanguagePattern?.trim() ||
      second[second.length - 1]?.reflection.concreteObservation?.trim();

    if (earlySnippet && lateSnippet && earlySnippet.slice(0, 40) !== lateSnippet.slice(0, 40)) {
      return {
        text: "This month reads differently from the beginning.",
        entryIds: [first[0].id, second[second.length - 1].id],
        signal: "carried_differently",
        score: 60,
      };
    }
  }

  return null;
}

function pickLines(candidates: LineCandidate[]): ReflectiveRoundupLine[] {
  const usedSignals = new Set<ReflectiveRoundupSignal>();
  const sorted = [...candidates].sort((a, b) => b.score - a.score);
  const picked: ReflectiveRoundupLine[] = [];

  for (const candidate of sorted) {
    if (picked.length >= MAX_LINES) break;
    if (usedSignals.has(candidate.signal)) continue;
    usedSignals.add(candidate.signal);
    picked.push({
      id: `roundup-${candidate.signal}-${picked.length}`,
      text: candidate.text,
      entryIds: candidate.entryIds,
      signal: candidate.signal,
      score: candidate.score,
    });
  }

  return picked;
}

export function buildWeeklyPeriod(endDayKey: string = todayKey()): RoundupPeriod {
  const startDayKey = addDaysToKey(endDayKey, -6);
  return {
    kind: "weekly",
    startDayKey,
    endDayKey,
    label: formatRangeLabel(startDayKey, endDayKey),
    slug: `week-${endDayKey}`,
  };
}

export function buildMonthlyPeriod(monthKey?: string): RoundupPeriod {
  const key = monthKey ?? todayKey().slice(0, 7);
  const [y, m] = key.split("-").map(Number);
  const startDayKey = `${key}-01`;
  const lastDay = new Date(y, m, 0).getDate();
  const endDayKey = `${key}-${String(lastDay).padStart(2, "0")}`;
  const end = endDayKey > todayKey() ? todayKey() : endDayKey;

  return {
    kind: "monthly",
    startDayKey,
    endDayKey: end,
    label: monthLabelFromKey(key),
    slug: `month-${key}`,
  };
}

export function buildCustomPeriod(startDayKey: string, endDayKey: string): RoundupPeriod {
  const start = startDayKey <= endDayKey ? startDayKey : endDayKey;
  const end = startDayKey <= endDayKey ? endDayKey : startDayKey;
  return {
    kind: "custom",
    startDayKey: start,
    endDayKey: end,
    label: formatRangeLabel(start, end),
    slug: `custom-${start}_${end}`,
  };
}

export function parsePeriodSlug(slug: string): RoundupPeriod | null {
  if (slug === "weekly" || slug === "week") {
    return buildWeeklyPeriod();
  }

  if (slug === "monthly" || slug === "month") {
    return buildMonthlyPeriod();
  }

  if (slug.startsWith("week-")) {
    const endDayKey = slug.slice(5);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(endDayKey)) return null;
    return buildWeeklyPeriod(endDayKey);
  }

  if (slug.startsWith("month-")) {
    const monthKey = slug.slice(6);
    if (!/^\d{4}-\d{2}$/.test(monthKey)) return null;
    return buildMonthlyPeriod(monthKey);
  }

  if (slug.startsWith("custom-")) {
    const range = slug.slice(7);
    const [startDayKey, endDayKey] = range.split("_");
    if (!startDayKey || !endDayKey) return null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(startDayKey) || !/^\d{4}-\d{2}-\d{2}$/.test(endDayKey)) {
      return null;
    }
    return buildCustomPeriod(startDayKey, endDayKey);
  }

  return null;
}

export function buildReflectiveRoundup(
  period: RoundupPeriod,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ReflectiveRoundup {
  const scoped = entriesInRange(entries, period.startDayKey, period.endDayKey);
  const candidates: LineCandidate[] = [];

  if (scoped.length === 0) {
    return {
      period,
      generatedAt: new Date().toISOString(),
      lines: [],
      hasData: false,
    };
  }

  const returned = detectReturned(scoped, period.kind);
  if (returned) candidates.push(returned);

  const faded = detectFaded(scoped);
  if (faded) candidates.push(faded);

  candidates.push(...detectToneAndClarity(scoped));

  const unfinished = detectUnfinished(scoped);
  if (unfinished) candidates.push(unfinished);

  const weight = detectWeight(scoped, period.kind);
  if (weight) candidates.push(weight);

  const revisited = detectRevisited(period, scoped);
  if (revisited) candidates.push(revisited);

  const carried = detectCarriedDifferently(scoped, period.kind);
  if (carried) candidates.push(carried);

  if (candidates.length === 0 && scoped.length >= 1) {
    const theme = scoped[scoped.length - 1].reflection.recurringThemes[0];
    candidates.push({
      text: theme
        ? `You kept returning to ${theme.toLowerCase()}.`
        : "Your voice kept circling the same ground.",
      entryIds: scoped.slice(-2).map((entry) => entry.id),
      signal: "returned",
      score: 55,
    });
  }

  return {
    period,
    generatedAt: new Date().toISOString(),
    lines: pickLines(candidates),
    hasData: scoped.length > 0,
  };
}

export function listReflectiveRoundups(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RoundupListReport {
  const end = todayKey();
  const thisWeek = buildWeeklyPeriod(end);
  const lastWeekEnd = addDaysToKey(startOfWeekKey(end), -1);
  const lastWeek = buildWeeklyPeriod(lastWeekEnd);
  const thisMonth = buildMonthlyPeriod();
  const prevMonthKey = (() => {
    const [y, m] = todayKey().slice(0, 7).split("-").map(Number);
    const date = new Date(y, m - 2, 1);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
  })();
  const lastMonth = buildMonthlyPeriod(prevMonthKey);

  const periods = [thisWeek, lastWeek, thisMonth, lastMonth];
  const items: RoundupIndexItem[] = periods.map((period) => {
    const roundup = buildReflectiveRoundup(period, entries);
    return {
      period,
      previewLine: roundup.lines[0]?.text,
      hasData: roundup.hasData,
    };
  });

  return {
    generatedAt: new Date().toISOString(),
    items: items.filter((item) => item.hasData),
  };
}

export function formatRoundupHref(period: RoundupPeriod): string {
  return `/roundups/${period.slug}`;
}
