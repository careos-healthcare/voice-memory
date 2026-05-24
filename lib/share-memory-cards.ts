import { addDaysToKey, todayKey, toDayKey } from "@/lib/dates";
import { buildEntityMemory } from "@/lib/entity-memory";
import { analyzeJournalEntries } from "@/lib/journal-analytics";
import { getSpecificReflectionView } from "@/lib/reflection";
import { getEntries } from "@/lib/storage";
import { getCachedWeeklySummary } from "@/lib/weekly-summary-cache";
import {
  analyzeWeeklyIntelligence,
  buildLocalWeeklySummary,
  type WeeklyIntelligenceReport,
} from "@/lib/weekly-intelligence";
import type { JournalEntry } from "@/types/journal";

export type ShareMemoryCardKind =
  | "weekly_summary"
  | "timeline_compression"
  | "memory_continuity"
  | "dominant_theme"
  | "entry_observation";

export const SHARE_CARD_DISCLAIMER =
  "This is a private reflection, not a diagnosis.";

const CARD_PREFIX = "VoiceMemory noticed:";

export interface ShareCardOptions {
  includeTranscript?: boolean;
}

function wrapCard(bodyLines: string[]): string {
  const lines = bodyLines.filter((line) => line.trim().length > 0);
  return [CARD_PREFIX, ...lines, "", SHARE_CARD_DISCLAIMER].join("\n");
}

function transcriptExcerpt(transcript: string | undefined, include: boolean): string | null {
  if (!include || !transcript?.trim()) return null;
  const trimmed = transcript.trim();
  const excerpt = trimmed.length > 220 ? `${trimmed.slice(0, 220)}…` : trimmed;
  return `From your words: "${excerpt}"`;
}

function latestEntryTranscript(): string | undefined {
  const entries = getEntries();
  return entries[0]?.transcript;
}

function countThemeMentionsLast30Days(theme: string): number {
  const cutoff = addDaysToKey(todayKey(), -29);
  const normalized = theme.trim().toLowerCase();
  let count = 0;
  for (const entry of getEntries()) {
    if (toDayKey(entry.createdAt) < cutoff) continue;
    for (const t of entry.reflection.recurringThemes) {
      if (t.trim().toLowerCase() === normalized) count += 1;
    }
    const concern = entry.reflection.hiddenConcern.toLowerCase();
    if (concern.includes(normalized)) count += 1;
  }
  return count;
}

export function buildWeeklySummaryShareCard(options: ShareCardOptions = {}): string {
  const report = analyzeWeeklyIntelligence();
  if (!report.hasData) {
    return wrapCard([
      "Your weekly summary will appear after a few voice reflections this week.",
    ]);
  }

  const cached = getCachedWeeklySummary(report.weekEndingKey);
  const summary = cached ?? buildLocalWeeklySummary(report);
  const lines = [
    `Week of ${report.weekRangeLabel}.`,
    summary,
  ];

  const excerpt = transcriptExcerpt(latestEntryTranscript(), Boolean(options.includeTranscript));
  if (excerpt) lines.push(excerpt);

  return wrapCard(lines);
}

export function buildTimelineCompressionShareCard(options: ShareCardOptions = {}): string {
  const report = analyzeWeeklyIntelligence();
  if (!report.hasData) {
    return wrapCard(["Not enough reflections yet to compress your week into a timeline."]);
  }

  const lines = compressWeekTimeline(report);
  const excerpt = transcriptExcerpt(latestEntryTranscript(), Boolean(options.includeTranscript));
  if (excerpt) lines.push(excerpt);

  return wrapCard(lines);
}

function compressWeekTimeline(report: WeeklyIntelligenceReport): string[] {
  const { thisWeek, emotionalShift } = report;
  const activeDays = thisWeek.intensityByDay.filter((d) => d.entryCount > 0);
  const lines: string[] = [
    `${thisWeek.entryCount} reflection${thisWeek.entryCount === 1 ? "" : "s"} across ${activeDays.length} day${activeDays.length === 1 ? "" : "s"} this week.`,
  ];

  if (activeDays.length >= 2) {
    const first = activeDays[0];
    const last = activeDays[activeDays.length - 1];
    if (first.avgIntensity !== last.avgIntensity) {
      lines.push(
        `My intensity moved from ${first.avgIntensity}/10 (${first.shortLabel}) to ${last.avgIntensity}/10 (${last.shortLabel}).`,
      );
    } else {
      lines.push(`Intensity held around ${first.avgIntensity}/10 most of the week.`);
    }
  } else if (activeDays.length === 1) {
    lines.push(`Peak day: ${activeDays[0].label} at ${activeDays[0].avgIntensity}/10.`);
  }

  if (emotionalShift.intensityDelta !== null && Math.abs(emotionalShift.intensityDelta) >= 0.5) {
    lines.push(emotionalShift.detail);
  }

  const busiest = [...thisWeek.entryTimeline].sort((a, b) => b.count - a.count)[0];
  if (busiest && busiest.count > 1) {
    lines.push(`Most check-ins landed on ${busiest.label} (${busiest.count} entries).`);
  }

  return lines;
}

export function buildMemoryContinuityShareCard(options: ShareCardOptions = {}): string {
  const insights = analyzeJournalEntries();
  const report = analyzeWeeklyIntelligence();
  const entity = buildEntityMemory();

  const lines: string[] = [];

  const highlight = entity.mentionHighlights[0];
  if (highlight && highlight.mentionCount >= 2) {
    lines.push(
      `I mentioned ${highlight.name} ${highlight.mentionCount} times in my recent reflections.`,
    );
  }

  const weeklyTop = insights.weeklyMentions[0];
  if (weeklyTop && weeklyTop.count >= 2) {
    const monthCount = countThemeMentionsLast30Days(weeklyTop.label);
    if (monthCount > weeklyTop.count) {
      lines.push(
        `I mentioned ${weeklyTop.label} ${monthCount} times this month — it keeps returning.`,
      );
    } else {
      lines.push(
        `I mentioned ${weeklyTop.label} ${weeklyTop.count} times this week.`,
      );
    }
  }

  if (report.hasData && report.comparison.topTheme.thisWeek && report.comparison.topTheme.lastWeek) {
    const { thisWeek, lastWeek } = report.comparison.topTheme;
    if (thisWeek === lastWeek) {
      lines.push(`"${thisWeek}" stayed on my mind two weeks in a row.`);
    }
  }

  if (insights.mostRepeatedPattern) {
    lines.push(`A recurring pattern: ${insights.mostRepeatedPattern}.`);
  }

  if (lines.length === 0) {
    lines.push(
      "Themes you keep returning to show up after a few days of recording.",
    );
  }

  const excerpt = transcriptExcerpt(latestEntryTranscript(), Boolean(options.includeTranscript));
  if (excerpt) lines.push(excerpt);

  return wrapCard(lines);
}

export function buildDominantThemeShareCard(options: ShareCardOptions = {}): string {
  const insights = analyzeJournalEntries();
  const report = analyzeWeeklyIntelligence();

  const theme =
    report.thisWeek.recurringThemes[0]?.label ??
    insights.recurringThemes[0]?.theme ??
    null;
  const count =
    report.thisWeek.recurringThemes[0]?.count ??
    insights.recurringThemes[0]?.count ??
    0;

  if (!theme) {
    return wrapCard(["Dominant themes will surface as you add more voice reflections."]);
  }

  const lines = [
    `"${theme}" has been my dominant theme (${count} mention${count === 1 ? "" : "s"} recently).`,
  ];

  const mood = report.thisWeek.dominantEmotions[0]?.label ?? insights.dominantMoods[0]?.mood;
  if (mood) {
    lines.push(`Emotional tone around it often felt ${mood}.`);
  }

  const excerpt = transcriptExcerpt(latestEntryTranscript(), Boolean(options.includeTranscript));
  if (excerpt) lines.push(excerpt);

  return wrapCard(lines);
}

export function buildEntryObservationShareCard(
  entry: JournalEntry,
  options: ShareCardOptions = {},
): string {
  const specific = getSpecificReflectionView(entry.reflection);
  const lines = [
    specific.concreteObservation,
    `Mood: ${entry.reflection.mood} · intensity ${entry.reflection.emotionalIntensity}/10.`,
  ];

  if (entry.reflection.recurringThemes.length > 0) {
    lines.push(`Themes: ${entry.reflection.recurringThemes.join(", ")}.`);
  }

  const excerpt = transcriptExcerpt(entry.transcript, Boolean(options.includeTranscript));
  if (excerpt) lines.push(excerpt);

  return wrapCard(lines);
}

export function buildShareCardText(
  kind: ShareMemoryCardKind,
  options: ShareCardOptions & { entry?: JournalEntry } = {},
): string {
  switch (kind) {
    case "weekly_summary":
      return buildWeeklySummaryShareCard(options);
    case "timeline_compression":
      return buildTimelineCompressionShareCard(options);
    case "memory_continuity":
      return buildMemoryContinuityShareCard(options);
    case "dominant_theme":
      return buildDominantThemeShareCard(options);
    case "entry_observation":
      if (!options.entry) {
        return wrapCard(["No entry selected for this observation."]);
      }
      return buildEntryObservationShareCard(options.entry, options);
    default:
      return wrapCard(["Unable to build this memory card."]);
  }
}
