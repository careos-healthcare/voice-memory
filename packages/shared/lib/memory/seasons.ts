import { toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import type {
  MemorySeason,
  MemorySeasonCopyExample,
  MemorySeasonKind,
  MemorySeasonObservation,
  MemorySeasonPeriod,
  MemorySeasonPeriodType,
  MemorySeasonReport,
} from "@/types/memory-season";
import type { JournalEntry } from "@/types/journal";

const MIN_PERIOD_ENTRIES = 1;
const MIN_OBSERVATION_ENTRIES = 2;
const ARCHIVE_MIN = 12;

const UNCERTAINTY_RE =
  /\b(not sure|unclear|uncertain|worried|anxious|maybe|don't know|unresolved)\b/gi;
const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually)\b/gi;

type CalendarSeason = "spring" | "summer" | "autumn" | "winter";

interface PeriodBucket {
  type: MemorySeasonPeriodType;
  key: string;
  label: string;
  slug: string;
  entries: JournalEntry[];
}

export const MEMORY_SEASON_COPY_EXAMPLES: MemorySeasonCopyExample[] = [
  {
    kind: "lighter_period",
    message: "Spring sounded lighter.",
    whenShown: "A calendar season had lower average emotional intensity than your archive baseline",
  },
  {
    kind: "heavier_period",
    message: "Last winter carried more uncertainty.",
    whenShown: "A winter period had higher intensity or more uncertain language than usual",
  },
  {
    kind: "dominant_focus",
    message: "For a while, work became quieter.",
    whenShown: "One theme dominated a period and softened toward the end",
  },
  {
    kind: "repeated_theme",
    message: "Work kept returning this season.",
    whenShown: "A theme appeared across the same calendar season in an earlier year",
  },
  {
    kind: "faded_theme",
    message: "Anxiety faded as the season went on.",
    whenShown: "A recurring theme was strong early in a period but absent toward the end",
  },
];

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function calendarSeason(month: number): CalendarSeason {
  if (month >= 3 && month <= 5) return "spring";
  if (month >= 6 && month <= 8) return "summer";
  if (month >= 9 && month <= 11) return "autumn";
  return "winter";
}

function seasonYear(iso: string): number {
  const [y, m] = toDayKey(iso).split("-").map(Number);
  if (m === 12) return y + 1;
  if (m <= 2) return y;
  return y;
}

function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function formatSeasonLabel(season: CalendarSeason, year: number): string {
  return `${capitalize(season)} ${year}`;
}

function formatMonthLabel(monthKey: string): string {
  const [y, m] = monthKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    year: "numeric",
  }).format(new Date(y, m - 1, 1));
}

function toSlug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .slice(0, 56);
}

function isLastWinter(season: CalendarSeason, year: number, now = new Date()): boolean {
  if (season !== "winter") return false;
  const currentMonth = now.getMonth() + 1;
  const currentYear = now.getFullYear();
  const currentWinterYear = currentMonth === 12 ? currentYear + 1 : currentMonth <= 2 ? currentYear : null;
  if (currentWinterYear === null) {
    return year === currentYear || year === currentYear - 1;
  }
  return year === currentWinterYear - 1 || (currentMonth <= 2 && year === currentWinterYear);
}

function themeCounts(entries: JournalEntry[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.trim().toLowerCase();
      if (key.length < 3) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  return counts;
}

function displayTheme(key: string, entries: JournalEntry[]): string {
  for (const entry of entries) {
    const match = entry.reflection.recurringThemes.find(
      (theme) => theme.trim().toLowerCase() === key,
    );
    if (match) return match.trim();
  }
  return capitalize(key);
}

function buildSeasonBuckets(sorted: JournalEntry[]): PeriodBucket[] {
  const seasonMap = new Map<string, PeriodBucket>();
  const monthMap = new Map<string, PeriodBucket>();

  for (const entry of sorted) {
    const [y, m] = toDayKey(entry.createdAt).split("-").map(Number);
    const season = calendarSeason(m);
    const sy = seasonYear(entry.createdAt);
    const seasonKey = `${season}-${sy}`;
    const seasonLabel = formatSeasonLabel(season, sy);
    let seasonBucket = seasonMap.get(seasonKey);
    if (!seasonBucket) {
      seasonBucket = {
        type: "calendar_season",
        key: seasonKey,
        label: seasonLabel,
        slug: toSlug(seasonLabel),
        entries: [],
      };
      seasonMap.set(seasonKey, seasonBucket);
    }
    seasonBucket.entries.push(entry);

    const monthKey = `${y}-${String(m).padStart(2, "0")}`;
    const monthLabel = formatMonthLabel(monthKey);
    let monthBucket = monthMap.get(monthKey);
    if (!monthBucket) {
      monthBucket = {
        type: "month",
        key: monthKey,
        label: monthLabel,
        slug: toSlug(monthLabel),
        entries: [],
      };
      monthMap.set(monthKey, monthBucket);
    }
    monthBucket.entries.push(entry);
  }

  const seasons = [...seasonMap.values()].filter(
    (bucket) => bucket.entries.length >= MIN_PERIOD_ENTRIES,
  );
  const months = [...monthMap.values()].filter(
    (bucket) => bucket.entries.length >= MIN_PERIOD_ENTRIES,
  );

  return [...seasons, ...months].sort(
    (a, b) =>
      new Date(b.entries[b.entries.length - 1].createdAt).getTime() -
      new Date(a.entries[a.entries.length - 1].createdAt).getTime(),
  );
}

function toPeriod(bucket: PeriodBucket, slugCounts: Map<string, number>): MemorySeasonPeriod {
  const entries = sortedEntries(bucket.entries);
  const first = entries[0];
  const last = entries[entries.length - 1];
  const baseSlug = bucket.slug;
  const count = (slugCounts.get(baseSlug) ?? 0) + 1;
  slugCounts.set(baseSlug, count);
  const slug = count > 1 ? `${baseSlug}-${bucket.type}` : baseSlug;

  return {
    id: `${bucket.type}-${bucket.key}`,
    slug,
    type: bucket.type,
    label: bucket.label,
    startAt: first.createdAt,
    endAt: last.createdAt,
    entryIds: entries.map((entry) => entry.id),
    entryCount: entries.length,
  };
}

function detectLighterHeavier(
  periodEntries: JournalEntry[],
  archiveAvg: number,
  periodLabel: string,
  season: CalendarSeason | null,
  seasonYearNum: number | null,
): MemorySeasonObservation[] {
  if (periodEntries.length < MIN_OBSERVATION_ENTRIES) return [];

  const avg = roundAvg(periodEntries.map((entry) => entry.reflection.emotionalIntensity));
  const uncertainty = roundAvg(
    periodEntries.map(
      (entry) =>
        countMatches(entry.transcript, UNCERTAINTY_RE) +
        countMatches(entry.reflection.hiddenConcern ?? "", UNCERTAINTY_RE),
    ),
  );
  const archiveUncertaintyBaseline = 1.2;
  const observations: MemorySeasonObservation[] = [];

  if (avg <= archiveAvg - 1) {
    const text =
      season === "spring"
        ? "Spring sounded lighter."
        : `${periodLabel} sounded lighter.`;
    observations.push({
      id: `season-lighter-${periodLabel}`,
      kind: "lighter_period",
      text,
    });
  }

  const isHeavy =
    avg >= archiveAvg + 1 ||
    (uncertainty >= archiveUncertaintyBaseline + 0.8 && avg >= archiveAvg - 0.5);

  if (isHeavy) {
    let text = `${periodLabel} carried more weight.`;
    if (season === "winter" && seasonYearNum !== null && isLastWinter(season, seasonYearNum)) {
      text = uncertainty >= archiveUncertaintyBaseline
        ? "Last winter carried more uncertainty."
        : "Last winter carried more weight.";
    } else if (uncertainty >= archiveUncertaintyBaseline + 0.5) {
      text = `${periodLabel} carried more uncertainty.`;
    }
    observations.push({
      id: `season-heavier-${periodLabel}`,
      kind: "heavier_period",
      text,
    });
  }

  return observations;
}

function detectRepeatedThemes(
  periodEntries: JournalEntry[],
  allSorted: JournalEntry[],
  periodLabel: string,
  season: CalendarSeason | null,
  seasonYearNum: number | null,
): MemorySeasonObservation[] {
  if (!season || seasonYearNum === null || periodEntries.length < MIN_OBSERVATION_ENTRIES) {
    return [];
  }

  const currentCounts = themeCounts(periodEntries);
  const priorSameSeason = allSorted.filter((entry) => {
    const [y, m] = toDayKey(entry.createdAt).split("-").map(Number);
    return calendarSeason(m) === season && seasonYear(entry.createdAt) < seasonYearNum;
  });
  if (priorSameSeason.length === 0) return [];

  const priorCounts = themeCounts(priorSameSeason);
  const observations: MemorySeasonObservation[] = [];

  for (const [themeKey, count] of currentCounts) {
    if (count < 2) continue;
    if ((priorCounts.get(themeKey) ?? 0) < 1) continue;
    const subject = displayTheme(themeKey, periodEntries);
    observations.push({
      id: `season-repeat-${periodLabel}-${themeKey}`,
      kind: "repeated_theme",
      text: `${subject} kept returning this season.`,
      subject,
    });
    break;
  }

  return observations;
}

function detectFadedThemes(
  periodEntries: JournalEntry[],
  periodLabel: string,
): MemorySeasonObservation[] {
  if (periodEntries.length < MIN_OBSERVATION_ENTRIES + 1) return [];

  const sorted = sortedEntries(periodEntries);
  const earlyEnd = Math.max(1, Math.floor(sorted.length / 2));
  const lateStart = Math.max(earlyEnd + 1, Math.ceil(sorted.length * 0.66));
  const early = sorted.slice(0, earlyEnd);
  const late = sorted.slice(lateStart);
  if (late.length === 0) return [];

  const earlyCounts = themeCounts(early);
  const lateCounts = themeCounts(late);
  const observations: MemorySeasonObservation[] = [];

  for (const [themeKey, count] of earlyCounts) {
    if (count < 2) continue;
    if ((lateCounts.get(themeKey) ?? 0) > 0) continue;
    const subject = displayTheme(themeKey, sorted);
    observations.push({
      id: `season-faded-${periodLabel}-${themeKey}`,
      kind: "faded_theme",
      text: `${subject} faded as the season went on.`,
      subject,
    });
    break;
  }

  return observations;
}

function detectDominantFocus(
  periodEntries: JournalEntry[],
  periodLabel: string,
): MemorySeasonObservation[] {
  if (periodEntries.length < MIN_OBSERVATION_ENTRIES) return [];

  const sorted = sortedEntries(periodEntries);
  const themeCount = themeCounts(sorted);
  let topTheme: { key: string; count: number } | null = null;
  for (const [key, count] of themeCount) {
    if (!topTheme || count > topTheme.count) {
      topTheme = { key, count };
    }
  }

  const entitySnapshot = buildEntityMemoryFromEntries(sorted);
  const dominantPerson = entitySnapshot.people[0];
  const dominantTopic = entitySnapshot.topics[0];

  const observations: MemorySeasonObservation[] = [];

  if (topTheme && topTheme.count >= 2) {
    const subject = displayTheme(topTheme.key, sorted);
    const subjectEntries = sorted.filter((entry) =>
      entry.reflection.recurringThemes.some(
        (theme) => theme.trim().toLowerCase() === topTheme!.key,
      ),
    );
    const half = Math.floor(subjectEntries.length / 2);
    const earlyAvg = roundAvg(
      subjectEntries.slice(0, Math.max(1, half)).map((e) => e.reflection.emotionalIntensity),
    );
    const lateAvg = roundAvg(
      subjectEntries.slice(Math.max(1, half)).map((e) => e.reflection.emotionalIntensity),
    );
    const lateHedge = roundAvg(
      subjectEntries.slice(Math.max(1, half)).map((e) => countMatches(e.transcript, HEDGE_RE)),
    );
    const earlyHedge = roundAvg(
      subjectEntries.slice(0, Math.max(1, half)).map((e) => countMatches(e.transcript, HEDGE_RE)),
    );

    const becameQuieter =
      lateAvg <= earlyAvg - 1 || (lateHedge <= earlyHedge - 0.8 && lateAvg <= earlyAvg);

    if (becameQuieter) {
      observations.push({
        id: `season-dominant-quiet-${periodLabel}-${topTheme.key}`,
        kind: "dominant_focus",
        text: `For a while, ${subject.toLowerCase()} became quieter.`,
        subject,
      });
    } else {
      observations.push({
        id: `season-dominant-${periodLabel}-${topTheme.key}`,
        kind: "dominant_focus",
        text: `For a while, this was mostly about ${subject.toLowerCase()}.`,
        subject,
      });
    }
    return observations;
  }

  if (dominantPerson && dominantPerson.mentionCount >= 2) {
    observations.push({
      id: `season-person-${periodLabel}-${dominantPerson.id}`,
      kind: "dominant_focus",
      text: `${periodLabel} kept returning to ${dominantPerson.name.toLowerCase()}.`,
      subject: dominantPerson.name,
    });
    return observations;
  }

  if (dominantTopic && dominantTopic.mentionCount >= 2) {
    observations.push({
      id: `season-topic-${periodLabel}-${dominantTopic.id}`,
      kind: "dominant_focus",
      text: `For a while, this was mostly about ${dominantTopic.name.toLowerCase()}.`,
      subject: dominantTopic.name,
    });
  }

  return observations;
}

function pickHeadline(observations: MemorySeasonObservation[]): string {
  const priority: MemorySeasonKind[] = [
    "lighter_period",
    "heavier_period",
    "dominant_focus",
    "repeated_theme",
    "faded_theme",
  ];
  for (const kind of priority) {
    const match = observations.find((observation) => observation.kind === kind);
    if (match) return match.text;
  }
  return "";
}

function parseSeasonFromLabel(
  label: string,
): { season: CalendarSeason; year: number } | null {
  const match = label.match(/^(Spring|Summer|Autumn|Winter)\s+(\d{4})$/i);
  if (!match) return null;
  return {
    season: match[1].toLowerCase() as CalendarSeason,
    year: Number(match[2]),
  };
}

function buildSeasonFromBucket(
  bucket: PeriodBucket,
  allSorted: JournalEntry[],
  archiveAvg: number,
  slugCounts: Map<string, number>,
): MemorySeason {
  const periodEntries = sortedEntries(bucket.entries);
  const period = toPeriod(bucket, slugCounts);
  const parsed = bucket.type === "calendar_season" ? parseSeasonFromLabel(bucket.label) : null;

  const observations = [
    ...detectLighterHeavier(
      periodEntries,
      archiveAvg,
      bucket.label,
      parsed?.season ?? null,
      parsed?.year ?? null,
    ),
    ...detectRepeatedThemes(
      periodEntries,
      allSorted,
      bucket.label,
      parsed?.season ?? null,
      parsed?.year ?? null,
    ),
    ...detectFadedThemes(periodEntries, bucket.label),
    ...detectDominantFocus(periodEntries, bucket.label),
  ];

  const deduped = observations.filter(
    (observation, index, list) =>
      list.findIndex((item) => item.text === observation.text) === index,
  );

  const headline =
    pickHeadline(deduped) ||
    (period.entryCount === 1
      ? `One reflection from ${bucket.label.toLowerCase()}.`
      : `${period.entryCount} reflections from ${bucket.label.toLowerCase()}.`);

  return {
    period,
    headline,
    observations: deduped,
  };
}

/** Group entries into calendar seasons and monthly periods with quiet temporal copy. */
export function buildMemorySeasonsReport(entries: JournalEntry[]): MemorySeasonReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < ARCHIVE_MIN) {
    return { seasons: [], hasData: false };
  }

  const archiveAvg = roundAvg(sorted.map((entry) => entry.reflection.emotionalIntensity));
  const buckets = buildSeasonBuckets(sorted);
  const slugCounts = new Map<string, number>();

  const seasons = buckets.map((bucket) =>
    buildSeasonFromBucket(bucket, sorted, archiveAvg, slugCounts),
  );

  return { seasons, hasData: seasons.length > 0 };
}

export function listMemorySeasons(entries: JournalEntry[], limit?: number): MemorySeason[] {
  const { seasons } = buildMemorySeasonsReport(entries);
  return limit ? seasons.slice(0, limit) : seasons;
}

export function getMemorySeasonBySlug(
  entries: JournalEntry[],
  slug: string,
): MemorySeason | null {
  const { seasons } = buildMemorySeasonsReport(entries);
  return seasons.find((season) => season.period.slug === slug) ?? null;
}

export function formatSeasonPeriodType(type: MemorySeasonPeriodType): string {
  return type === "calendar_season" ? "Season" : "Month";
}

export function calendarSeasonsOnly(seasons: MemorySeason[]): MemorySeason[] {
  return seasons.filter((season) => season.period.type === "calendar_season");
}

export function monthlyPeriodsOnly(seasons: MemorySeason[]): MemorySeason[] {
  return seasons.filter((season) => season.period.type === "month");
}

export interface SeasonDepthSignals {
  distinguishablePeriodCount: number;
  toneShiftPeriodCount: number;
  calendarSeasonCount: number;
  recurringAcrossYears: number;
}

/** Measure seasonal distinguishability for archive-depth — internal scoring only. */
export function measureSeasonDepthSignals(entries: JournalEntry[]): SeasonDepthSignals {
  const { seasons } = buildMemorySeasonsReport(entries);
  const calendar = calendarSeasonsOnly(seasons);

  let toneShiftPeriodCount = 0;
  let recurringAcrossYears = 0;

  for (const season of seasons) {
    const hasToneShift = season.observations.some(
      (observation) =>
        observation.kind === "lighter_period" ||
        observation.kind === "heavier_period" ||
        observation.kind === "faded_theme" ||
        observation.kind === "repeated_theme",
    );
    if (hasToneShift) toneShiftPeriodCount += 1;
    if (season.observations.some((observation) => observation.kind === "repeated_theme")) {
      recurringAcrossYears += 1;
    }
  }

  return {
    distinguishablePeriodCount: seasons.filter(
      (season) => season.period.entryCount >= 2 && season.observations.length >= 1,
    ).length,
    toneShiftPeriodCount,
    calendarSeasonCount: calendar.length,
    recurringAcrossYears,
  };
}
