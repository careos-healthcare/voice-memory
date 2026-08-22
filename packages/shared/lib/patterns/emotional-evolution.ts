import { addDaysToKey, toDayKey } from "@/lib/dates";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export type EvolutionWindow = "7d" | "30d" | "all";

export type EvolutionInsightKind =
  | "day_of_week"
  | "intensity_drift"
  | "emotional_cycle"
  | "recurring_trigger"
  | "entity_topic_mood"
  | "period_comparison";

export interface EvolutionInsight {
  id: string;
  kind: EvolutionInsightKind;
  line: string;
  detail?: string;
  window: EvolutionWindow;
  confidence: number;
  entryIds: string[];
}

export interface WeeklyEvolutionComparison {
  thisWeekAvg: number | null;
  lastWeekAvg: number | null;
  intensityDelta: number | null;
  direction: "calmer" | "intenser" | "stable" | "mixed" | "unknown";
  lines: string[];
  insights: EvolutionInsight[];
}

export interface EmotionalEvolutionReport {
  insights: EvolutionInsight[];
  weekComparison: WeeklyEvolutionComparison;
}

const DAY_NAMES = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  return Math.round(avg * 10) / 10;
}

function dayName(iso: string): string {
  const [y, m, d] = toDayKey(iso).split("-").map(Number);
  return DAY_NAMES[new Date(y, m - 1, d).getDay()];
}

function timeSlot(iso: string): string {
  const hour = new Date(iso).getHours();
  if (hour >= 5 && hour < 12) return "mornings";
  if (hour >= 12 && hour < 17) return "afternoons";
  if (hour >= 17 && hour < 22) return "evenings";
  return "late nights";
}

function confidenceScore(entryCount: number, strength: number): number {
  return Math.min(100, entryCount * 18 + strength * 12 + (entryCount >= 3 ? 10 : 0));
}

function filterByWindow(entries: JournalEntry[], window: EvolutionWindow): JournalEntry[] {
  if (window === "all") return entries;
  const days = window === "7d" ? 7 : 30;
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return entries.filter((e) => toDayKey(e.createdAt) >= cutoff);
}

function entriesInRange(
  entries: JournalEntry[],
  startKey: string,
  endKey: string,
): JournalEntry[] {
  return entries.filter((e) => {
    const key = toDayKey(e.createdAt);
    return key >= startKey && key <= endKey;
  });
}

function analyzeDayOfWeekPatterns(
  entries: JournalEntry[],
  window: EvolutionWindow,
): EvolutionInsight[] {
  if (entries.length < 3) return [];

  const clusters = new Map<
    string,
    { intensities: number[]; entryIds: string[]; moods: string[] }
  >();

  for (const entry of entries) {
    const key = `${dayName(entry.createdAt)} ${timeSlot(entry.createdAt)}`;
    const row = clusters.get(key) ?? { intensities: [], entryIds: [], moods: [] };
    row.intensities.push(entry.reflection.emotionalIntensity);
    row.entryIds.push(entry.id);
    row.moods.push(entry.reflection.mood);
    clusters.set(key, row);
  }

  let best: { key: string; avg: number; row: (typeof clusters extends Map<string, infer V> ? V : never) } | null =
    null;

  for (const [key, row] of clusters.entries()) {
    if (row.intensities.length < 2) continue;
    const avg = roundAvg(row.intensities);
    if (!best || avg > best.avg) {
      best = { key, avg, row };
    }
  }

  if (!best || best.avg < 5) return [];

  const [day, slot] = best.key.split(" ");
  const slotLabel = slot === "evenings" ? "evenings" : slot;

  return [
    {
      id: `dow-${best.key.replace(/\s+/g, "-").toLowerCase()}-${window}`,
      kind: "day_of_week",
      line: `Your highest-intensity entries cluster on ${day} ${slotLabel}.`,
      detail: `${best.row.entryIds.length} reflections averaged ${best.avg}/10 — your charged language tends to land ${day} ${slotLabel}.`,
      window,
      confidence: confidenceScore(best.row.entryIds.length, best.avg - 4),
      entryIds: best.row.entryIds,
    },
  ];
}

function analyzeIntensityDrift(
  entries: JournalEntry[],
  window: EvolutionWindow,
): EvolutionInsight[] {
  if (entries.length < 4) return [];

  const mid = Math.floor(entries.length / 2);
  const firstHalf = entries.slice(0, mid);
  const secondHalf = entries.slice(mid);

  const firstAvg = roundAvg(firstHalf.map((e) => e.reflection.emotionalIntensity));
  const secondAvg = roundAvg(secondHalf.map((e) => e.reflection.emotionalIntensity));
  const delta = secondAvg - firstAvg;

  if (Math.abs(delta) < 1) return [];

  const windowLabel =
    window === "7d" ? "the last 7 days" : window === "30d" ? "the last 30 days" : "your archive";

  return [
    {
      id: `drift-${window}`,
      kind: "intensity_drift",
      line:
        delta > 0
          ? `Intensity climbed over ${windowLabel} (${firstAvg} → ${secondAvg}/10).`
          : `Intensity eased over ${windowLabel} (${firstAvg} → ${secondAvg}/10).`,
      detail:
        delta > 0
          ? `Earlier entries in this window averaged ${firstAvg}/10; recent ones hit ${secondAvg}/10.`
          : `Earlier entries averaged ${firstAvg}/10; recent ones dropped to ${secondAvg}/10.`,
      window,
      confidence: confidenceScore(entries.length, Math.abs(delta)),
      entryIds: entries.map((e) => e.id),
    },
  ];
}

function analyzeEmotionalCycles(
  entries: JournalEntry[],
  window: EvolutionWindow,
): EvolutionInsight[] {
  if (entries.length < 4) return [];

  const recent = entries.slice(-6);
  const moods = recent.map((e) => e.reflection.mood.toLowerCase());
  let alternations = 0;

  for (let i = 1; i < moods.length; i += 1) {
    if (moods[i] !== moods[i - 1]) alternations += 1;
  }

  if (alternations < moods.length - 2) return [];

  const sequence = recent.map((e) => e.reflection.mood).join(" → ");

  return [
    {
      id: `cycle-${window}`,
      kind: "emotional_cycle",
      line: `Recent moods swing often (${sequence}).`,
      detail: `Last ${recent.length} reflections cycle through ${alternations + 1} distinct moods without settling.`,
      window,
      confidence: confidenceScore(recent.length, alternations),
      entryIds: recent.map((e) => e.id),
    },
  ];
}

function analyzeTriggerContexts(
  entries: JournalEntry[],
  window: EvolutionWindow,
): EvolutionInsight[] {
  const themeData = new Map<string, { intensities: number[]; entryIds: string[] }>();

  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase().trim();
      if (!key) continue;
      const row = themeData.get(key) ?? { intensities: [], entryIds: [] };
      row.intensities.push(entry.reflection.emotionalIntensity);
      row.entryIds.push(entry.id);
      themeData.set(key, row);
    }
  }

  const results: EvolutionInsight[] = [];

  for (const [theme, row] of themeData.entries()) {
    if (row.intensities.length < 2) continue;
    const avg = roundAvg(row.intensities);
    if (avg < 5.5) continue;

    results.push({
      id: `trigger-${theme}-${window}`,
      kind: "recurring_trigger",
      line: `"${capitalize(theme)}" entries run ${avg}/10 — hotter than your typical reflections.`,
      detail: `${row.entryIds.length} entries tag "${theme}" when your language carries more charge.`,
      window,
      confidence: confidenceScore(row.entryIds.length, avg - 4),
      entryIds: [...new Set(row.entryIds)],
    });
  }

  return results.sort((a, b) => b.confidence - a.confidence).slice(0, 3);
}

function analyzeTopicIntensityShift(entries: JournalEntry[]): EvolutionInsight[] {
  const today = toDayKey(new Date().toISOString());
  const twoWeeksAgo = addDaysToKey(today, -13);
  const oneWeekAgo = addDaysToKey(today, -6);

  const recentWeek = entriesInRange(entries, oneWeekAgo, today);
  const priorWeek = entriesInRange(entries, twoWeeksAgo, addDaysToKey(oneWeekAgo, -1));

  if (recentWeek.length < 2 || priorWeek.length < 2) return [];

  const themeWeek = (list: JournalEntry[]) => {
    const map = new Map<string, number[]>();
    for (const entry of list) {
      for (const theme of entry.reflection.recurringThemes) {
        const key = theme.toLowerCase().trim();
        if (!key) continue;
        const row = map.get(key) ?? [];
        row.push(entry.reflection.emotionalIntensity);
        map.set(key, row);
      }
    }
    return map;
  };

  const recent = themeWeek(recentWeek);
  const prior = themeWeek(priorWeek);
  const results: EvolutionInsight[] = [];

  for (const [theme, recentInts] of recent.entries()) {
    const priorInts = prior.get(theme);
    if (!priorInts || priorInts.length < 1 || recentInts.length < 1) continue;

    const recentAvg = roundAvg(recentInts);
    const priorAvg = roundAvg(priorInts);
    const delta = recentAvg - priorAvg;

    if (Math.abs(delta) < 1.2) continue;

    results.push({
      id: `topic-shift-${theme}`,
      kind: "entity_topic_mood",
      line:
        delta < 0
          ? `${capitalize(theme)} mentions became less intense over the last 2 weeks (${priorAvg} → ${recentAvg}/10).`
          : `${capitalize(theme)} mentions became more intense over the last 2 weeks (${priorAvg} → ${recentAvg}/10).`,
      detail: `Week-over-week intensity when "${theme}" appeared: ${priorAvg}/10 → ${recentAvg}/10.`,
      window: "30d",
      confidence: confidenceScore(recentInts.length + priorInts.length, Math.abs(delta)),
      entryIds: [...recentWeek, ...priorWeek]
        .filter((e) =>
          e.reflection.recurringThemes.some((t) => t.toLowerCase() === theme),
        )
        .map((e) => e.id),
    });
  }

  return results.sort((a, b) => b.confidence - a.confidence).slice(0, 2);
}

function analyzePeriodComparison(entries: JournalEntry[]): EvolutionInsight[] {
  if (entries.length < 4) return [];

  const today = toDayKey(new Date().toISOString());
  const weekAgo = addDaysToKey(today, -6);
  const twoWeeksAgo = addDaysToKey(today, -13);

  const thisWeek = entriesInRange(entries, weekAgo, today);
  const lastWeek = entriesInRange(entries, twoWeeksAgo, addDaysToKey(weekAgo, -1));

  if (thisWeek.length < 2 || lastWeek.length < 2) return [];

  const thisAvg = roundAvg(thisWeek.map((e) => e.reflection.emotionalIntensity));
  const lastAvg = roundAvg(lastWeek.map((e) => e.reflection.emotionalIntensity));
  const delta = thisAvg - lastAvg;

  if (Math.abs(delta) < 0.8) {
    return [
      {
        id: "period-stable",
        kind: "period_comparison",
        line: `Intensity stayed steady this week vs last (${thisAvg}/10 both periods).`,
        detail: "Both weeks landed at similar average intensity in your words.",
        window: "7d",
        confidence: confidenceScore(thisWeek.length + lastWeek.length, 1),
        entryIds: [...thisWeek, ...lastWeek].map((e) => e.id),
      },
    ];
  }

  return [
    {
      id: "period-comparison",
      kind: "period_comparison",
      line:
        delta < 0
          ? `This week was calmer than last week (${thisAvg}/10 vs ${lastAvg}/10 average intensity).`
          : `This week was more intense than last week (${thisAvg}/10 vs ${lastAvg}/10 average intensity).`,
      detail:
        delta < 0
          ? `This week's entries averaged ${thisAvg}/10 vs ${lastAvg}/10 last week — less charged overall.`
          : `This week's entries averaged ${thisAvg}/10 vs ${lastAvg}/10 last week — more charged overall.`,
      window: "7d",
      confidence: confidenceScore(thisWeek.length + lastWeek.length, Math.abs(delta)),
      entryIds: [...thisWeek, ...lastWeek].map((e) => e.id),
    },
  ];
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const HEDGE_RE =
  /\b(maybe|sort of|kind of|probably|not sure|something|stuff|indirectly|i guess)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|mum|dad|mother|father|clearly|for sure|definitely|plan)\b/gi;

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

/** Whether an entry tags a recurring theme (case-insensitive). */
export function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

/** Hedge vs direct language shift between two entries on the same thread. */
export function languageShiftOnTheme(
  prior: JournalEntry,
  current: JournalEntry,
): { hedgeDelta: number; directDelta: number } {
  const priorHedge = countMatches(prior.transcript, HEDGE_RE);
  const nowHedge = countMatches(current.transcript, HEDGE_RE);
  const priorDirect = countMatches(prior.transcript, DIRECT_RE);
  const nowDirect = countMatches(current.transcript, DIRECT_RE);
  return {
    hedgeDelta: priorHedge - nowHedge,
    directDelta: nowDirect - priorDirect,
  };
}

/** Peak-to-now intensity drop for a theme across chronological mentions. */
export function getThemeIntensityTrend(
  entries: JournalEntry[],
  themeKey: string,
): { peakEntry: JournalEntry; delta: number; mentions: number } | null {
  const hits = entries.filter((e) => hasTheme(e, themeKey));
  if (hits.length < 3) return null;

  const peakEntry = hits.reduce((best, e) =>
    e.reflection.emotionalIntensity > best.reflection.emotionalIntensity ? e : best,
  );
  const latest = hits[hits.length - 1];
  const delta = peakEntry.reflection.emotionalIntensity - latest.reflection.emotionalIntensity;
  if (delta < 1.5) return null;

  return { peakEntry, delta, mentions: hits.length };
}

function buildInsightsForWindow(
  allEntries: JournalEntry[],
  window: EvolutionWindow,
): EvolutionInsight[] {
  const scoped = filterByWindow(allEntries, window);
  if (scoped.length < 2) return [];

  return [
    ...analyzeDayOfWeekPatterns(scoped, window),
    ...analyzeIntensityDrift(scoped, window),
    ...analyzeEmotionalCycles(scoped, window),
    ...analyzeTriggerContexts(scoped, window),
  ];
}

/** Full emotional evolution report across windows. */
export function buildEmotionalEvolutionReport(
  entries: JournalEntry[],
): EmotionalEvolutionReport {
  const sorted = sortedEntries(entries);
  const insights: EvolutionInsight[] = [];

  for (const window of ["7d", "30d", "all"] as EvolutionWindow[]) {
    insights.push(...buildInsightsForWindow(sorted, window));
  }

  insights.push(...analyzeTopicIntensityShift(sorted));
  insights.push(...analyzePeriodComparison(sorted));

  const deduped = dedupeInsights(insights)
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 15);

  return {
    insights: deduped,
    weekComparison: buildWeeklyEvolutionComparison(sorted),
  };
}

function dedupeInsights(insights: EvolutionInsight[]): EvolutionInsight[] {
  const seen = new Set<string>();
  return insights.filter((i) => {
    const key = `${i.kind}:${i.line.slice(0, 40)}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** Insights filtered by window (default: all). */
export function getEvolutionInsights(
  entries: JournalEntry[],
  window: EvolutionWindow = "all",
): EvolutionInsight[] {
  const report = buildEmotionalEvolutionReport(entries);
  if (window === "all") return report.insights;
  return report.insights.filter((i) => i.window === window || i.kind === "entity_topic_mood");
}

/** Cycle and pattern insights for the insights page. */
export function getEmotionalCycleInsights(entries: JournalEntry[]): EvolutionInsight[] {
  return buildEmotionalEvolutionReport(entries).insights.filter((i) =>
    ["emotional_cycle", "day_of_week", "recurring_trigger", "intensity_drift"].includes(i.kind),
  );
}

/** This week vs previous week comparison with concrete lines. */
export function buildWeeklyEvolutionComparison(
  entries: JournalEntry[],
): WeeklyEvolutionComparison {
  const sorted = sortedEntries(entries);
  const today = toDayKey(new Date().toISOString());
  const weekStart = addDaysToKey(today, -6);
  const priorStart = addDaysToKey(today, -13);
  const priorEnd = addDaysToKey(weekStart, -1);

  const thisWeek = entriesInRange(sorted, weekStart, today);
  const lastWeek = entriesInRange(sorted, priorStart, priorEnd);

  const thisWeekAvg =
    thisWeek.length > 0
      ? roundAvg(thisWeek.map((e) => e.reflection.emotionalIntensity))
      : null;
  const lastWeekAvg =
    lastWeek.length > 0
      ? roundAvg(lastWeek.map((e) => e.reflection.emotionalIntensity))
      : null;

  let direction: WeeklyEvolutionComparison["direction"] = "unknown";
  let intensityDelta: number | null = null;
  const lines: string[] = [];

  if (thisWeekAvg !== null && lastWeekAvg !== null) {
    intensityDelta = Math.round((thisWeekAvg - lastWeekAvg) * 10) / 10;
    if (Math.abs(intensityDelta) < 0.8) direction = "stable";
    else if (intensityDelta > 0) direction = "intenser";
    else direction = "calmer";

    lines.push(
      direction === "calmer"
        ? `This week averaged ${thisWeekAvg}/10 intensity — calmer than last week's ${lastWeekAvg}/10.`
        : direction === "intenser"
          ? `This week averaged ${thisWeekAvg}/10 intensity — higher than last week's ${lastWeekAvg}/10.`
          : `This week and last week both averaged around ${thisWeekAvg}/10 intensity.`,
    );
  } else if (thisWeekAvg !== null) {
    lines.push(`This week's reflections averaged ${thisWeekAvg}/10 intensity.`);
  }

  const periodInsights = analyzePeriodComparison(sorted);
  const topicShifts = analyzeTopicIntensityShift(sorted);
  lines.push(...periodInsights.map((i) => i.line));
  lines.push(...topicShifts.map((i) => i.line));

  const uniqueLines = [...new Set(lines)].slice(0, 4);

  return {
    thisWeekAvg,
    lastWeekAvg,
    intensityDelta,
    direction,
    lines: uniqueLines,
    insights: [...periodInsights, ...topicShifts],
  };
}

/** Insights linked to a specific entry (for legacy InsightCard). */
export function getEvolutionForEntry(
  entries: JournalEntry[],
  entryId: string,
): EvolutionInsight[] {
  return buildEmotionalEvolutionReport(entries)
    .insights.filter((i) => i.entryIds.includes(entryId))
    .slice(0, 5);
}

export function confidenceLabel(score: number): string {
  if (score >= 70) return "Strong pattern";
  if (score >= 50) return "Moderate pattern";
  return "Possible pattern";
}

/** Adapter for legacy pattern-insights shape. */
export function toLegacyEmotionalEvolutionSignal(insight: EvolutionInsight): {
  id: string;
  label: string;
  detail: string;
  kind:
    | "intensity_drift"
    | "day_of_week"
    | "recurring_trigger"
    | "emotional_cycle"
    | "recurring_context";
} {
  const kindMap: Record<
    EvolutionInsightKind,
    | "intensity_drift"
    | "day_of_week"
    | "recurring_trigger"
    | "emotional_cycle"
    | "recurring_context"
  > = {
    day_of_week: "day_of_week",
    intensity_drift: "intensity_drift",
    emotional_cycle: "emotional_cycle",
    recurring_trigger: "recurring_trigger",
    entity_topic_mood: "recurring_trigger",
    period_comparison: "intensity_drift",
  };

  return {
    id: insight.id,
    kind: kindMap[insight.kind],
    label: insight.line,
    detail: insight.detail ?? insight.line,
  };
}

/** Per-entry legacy signals for InsightCard. */
export function detectEmotionalEvolutionForEntry(
  entries: JournalEntry[],
  entryId: string,
): ReturnType<typeof toLegacyEmotionalEvolutionSignal>[] {
  return getEvolutionForEntry(entries, entryId)
    .map(toLegacyEmotionalEvolutionSignal)
    .slice(0, 5);
}
