import { toDayKey } from "@/lib/dates";
import { buildEntityMemory } from "@/lib/entity-memory";
import { analyzeJournalEntries } from "@/lib/journal-analytics";
import { getSpecificReflectionView } from "@/lib/reflection";
import { getEntries } from "@/lib/storage";
import {
  analyzeWeeklyIntelligence,
  buildLocalWeeklySummary,
} from "@/lib/weekly-intelligence";
import { getCachedWeeklySummary } from "@/lib/weekly-summary-cache";
import type { JournalEntry } from "@/types/journal";

export const PRINT_REPORT_STORAGE_KEY = "voicememory_print_report";

export interface ExportJsonBundle {
  exportedAt: string;
  dateRange: { from: string | null; to: string | null };
  entryCount: number;
  entries: JournalEntry[];
}

export interface PrintableMoodPoint {
  label: string;
  avgIntensity: number;
  entryCount: number;
}

export interface PrintableThemeRow {
  theme: string;
  count: number;
}

export interface PrintableEntityRow {
  name: string;
  type: string;
  count: number;
}

export interface PrintableEntryExcerpt {
  id: string;
  dateLabel: string;
  mood: string;
  intensity: number;
  themes: string[];
  excerpt: string;
  observation: string;
}

export interface PrintableReport {
  generatedAt: string;
  dateRangeLabel: string;
  weekRangeLabel: string;
  weeklySummary: string;
  moodTimeline: PrintableMoodPoint[];
  recurringThemes: PrintableThemeRow[];
  recurringEntities: PrintableEntityRow[];
  entryExcerpts: PrintableEntryExcerpt[];
  totalEntries: number;
}

function formatDateLabel(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(iso));
}

function formatRangeLabel(from: string | null, to: string | null): string {
  if (!from && !to) return "All entries";
  if (from && to) return `${from} → ${to}`;
  if (from) return `From ${from}`;
  return `Through ${to}`;
}

export function filterEntriesByDateRange(
  entries: JournalEntry[],
  dateFrom: string,
  dateTo: string,
): JournalEntry[] {
  return entries.filter((entry) => {
    const day = toDayKey(entry.createdAt);
    if (dateFrom && day < dateFrom) return false;
    if (dateTo && day > dateTo) return false;
    return true;
  });
}

export function buildExportJsonBundle(
  dateFrom = "",
  dateTo = "",
): ExportJsonBundle {
  const all = getEntries();
  const entries =
    dateFrom || dateTo ? filterEntriesByDateRange(all, dateFrom, dateTo) : all;

  return {
    exportedAt: new Date().toISOString(),
    dateRange: {
      from: dateFrom || null,
      to: dateTo || null,
    },
    entryCount: entries.length,
    entries,
  };
}

export function downloadJsonFile(filename: string, data: unknown): void {
  const blob = new Blob([JSON.stringify(data, null, 2)], {
    type: "application/json",
  });
  triggerDownload(filename, blob);
}

export function downloadTextFile(filename: string, text: string): void {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  triggerDownload(filename, blob);
}

function triggerDownload(filename: string, blob: Blob): void {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function buildWeeklySummaryText(): string {
  const report = analyzeWeeklyIntelligence();
  const cached = getCachedWeeklySummary(report.weekEndingKey);
  const summary = cached ?? buildLocalWeeklySummary(report);

  const lines = [
    "VoiceMemory — Weekly Summary",
    `Generated: ${formatDateLabel(new Date().toISOString())}`,
    `Week: ${report.weekRangeLabel}`,
    "",
    summary,
    "",
    "---",
    `Entries this week: ${report.thisWeek.entryCount}`,
    `Dominant mood: ${report.thisWeek.dominantEmotions[0]?.label ?? "—"}`,
    `Top theme: ${report.thisWeek.recurringThemes[0]?.label ?? "—"}`,
    `Emotional shift: ${report.emotionalShift.label}`,
    report.emotionalShift.detail,
    "",
    "Exported from your device. Reflective mirror only — not therapy or diagnosis.",
  ];

  return lines.join("\n");
}

export function buildInsightsSummaryText(): string {
  const insights = analyzeJournalEntries();

  const lines = [
    "VoiceMemory — Insights Summary",
    `Generated: ${formatDateLabel(new Date().toISOString())}`,
    `Total entries: ${insights.totalEntries}`,
    "",
    "Dominant moods",
    ...insights.dominantMoods.map(
      (m) => `- ${m.mood}: ${m.count} (${m.share}%)`,
    ),
    "",
    "Recurring themes",
    ...insights.recurringThemes.map((t) => `- ${t.theme}: ${t.count}`),
    "",
    "Emotional intensity (last 14 days)",
    ...insights.intensityTrend
      .filter((p) => p.entryCount > 0)
      .map((p) => `- ${p.label}: ${p.avgIntensity}/10 (${p.entryCount} entries)`),
  ];

  if (insights.mostMentionedConcern) {
    lines.push("", `Most mentioned concern: ${insights.mostMentionedConcern}`);
  }

  if (insights.weeklyMentions.length > 0) {
    lines.push("", "This week in your words");
    for (const m of insights.weeklyMentions) {
      lines.push(`- You mentioned "${m.label}" ${m.count} times`);
    }
  }

  lines.push(
    "",
    "Exported from your device. Reflective mirror only — not therapy or diagnosis.",
  );
  return lines.join("\n");
}

function entryExcerpt(entry: JournalEntry): PrintableEntryExcerpt {
  const specific = getSpecificReflectionView(entry.reflection);
  const text =
    entry.reflection.concreteObservation?.trim() ||
    entry.transcript.trim().slice(0, 280) ||
    entry.reflection.positiveSignal;

  return {
    id: entry.id,
    dateLabel: formatDateLabel(entry.createdAt),
    mood: entry.reflection.mood,
    intensity: entry.reflection.emotionalIntensity,
    themes: entry.reflection.recurringThemes,
    excerpt:
      entry.transcript.length > 320
        ? `${entry.transcript.slice(0, 320)}…`
        : entry.transcript,
    observation: specific.concreteObservation,
  };
}

export function buildPrintableReport(options?: {
  dateFrom?: string;
  dateTo?: string;
  maxExcerpts?: number;
}): PrintableReport {
  const dateFrom = options?.dateFrom ?? "";
  const dateTo = options?.dateTo ?? "";
  const maxExcerpts = options?.maxExcerpts ?? 12;

  const all = getEntries();
  const scoped =
    dateFrom || dateTo
      ? filterEntriesByDateRange(all, dateFrom, dateTo)
      : all;

  const insights = analyzeJournalEntries();
  const weekly = analyzeWeeklyIntelligence();
  const entitySnapshot = buildEntityMemory();
  const cachedWeekly = getCachedWeeklySummary(weekly.weekEndingKey);

  const entities: PrintableEntityRow[] = [
    ...entitySnapshot.people,
    ...entitySnapshot.concerns,
    ...entitySnapshot.goals,
    ...entitySnapshot.topics,
  ]
    .slice(0, 12)
    .map((e) => ({
      name: e.name,
      type: e.type,
      count: e.mentionCount,
    }));

  const moodTimeline: PrintableMoodPoint[] = insights.intensityTrend
    .filter((p) => p.entryCount > 0)
    .map((p) => ({
      label: p.label,
      avgIntensity: p.avgIntensity,
      entryCount: p.entryCount,
    }));

  if (moodTimeline.length === 0 && weekly.hasData) {
    for (const p of weekly.thisWeek.intensityByDay) {
      if (p.entryCount > 0) {
        moodTimeline.push({
          label: p.label,
          avgIntensity: p.avgIntensity,
          entryCount: p.entryCount,
        });
      }
    }
  }

  const themes =
    insights.recurringThemes.length > 0
      ? insights.recurringThemes.map((t) => ({
          theme: t.theme,
          count: t.count,
        }))
      : weekly.thisWeek.recurringThemes.map((t) => ({
          theme: t.label,
          count: t.count,
        }));

  return {
    generatedAt: new Date().toISOString(),
    dateRangeLabel: formatRangeLabel(dateFrom || null, dateTo || null),
    weekRangeLabel: weekly.weekRangeLabel,
    weeklySummary: cachedWeekly ?? buildLocalWeeklySummary(weekly),
    moodTimeline,
    recurringThemes: themes,
    recurringEntities: entities,
    entryExcerpts: scoped.slice(0, maxExcerpts).map(entryExcerpt),
    totalEntries: scoped.length,
  };
}

export function openPrintableReport(report: PrintableReport): void {
  sessionStorage.setItem(PRINT_REPORT_STORAGE_KEY, JSON.stringify(report));
  window.open("/export/print", "_blank", "noopener,noreferrer");
}

export function readPrintableReportFromSession(): PrintableReport | null {
  try {
    const raw = sessionStorage.getItem(PRINT_REPORT_STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as PrintableReport;
  } catch {
    return null;
  }
}

export function slugExportDate(): string {
  return toDayKey(new Date());
}
