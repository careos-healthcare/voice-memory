import { startOfWeekKey, todayKey } from "@/lib/dates";
import { getCallbackPruningAction } from "@/lib/debug/callback-pruning";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { sortByEmotionalSurvival } from "@/lib/debug/callback-quality-score";
import {
  buildRetentionObservationSnapshot,
  getStudyAnchorDay,
  readManualStudyNotes,
} from "@/lib/research/retention-observation";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { getAllEntries } from "@/lib/storage";
import type {
  CallbackSurvivalSummaryRow,
  EmotionalResidueSummaryRow,
  ObservationSummariesExport,
  RevisitConversionSummary,
  WeeklyRetentionSnapshot,
} from "@/types/validation-phase";

const WEEKLY_SNAPSHOTS_KEY = "voicememory_weekly_retention_snapshots";
const MAX_WEEKS = 26;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readWeeklySnapshotsRaw(): WeeklyRetentionSnapshot[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(WEEKLY_SNAPSHOTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as WeeklyRetentionSnapshot[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeWeeklySnapshotsRaw(snapshots: WeeklyRetentionSnapshot[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(WEEKLY_SNAPSHOTS_KEY, JSON.stringify(snapshots.slice(-MAX_WEEKS)));
}

function pct(count: number, total: number): string {
  if (total <= 0) return "—";
  return `${Math.round((count / total) * 100)}%`;
}

/** Capture or refresh the current week's retention snapshot — local only. */
export async function captureWeeklyRetentionSnapshot(): Promise<WeeklyRetentionSnapshot> {
  const observation = await buildRetentionObservationSnapshot();
  const loops = buildRetentionLoopReport();
  const weekStart = startOfWeekKey(todayKey());

  const snapshot: WeeklyRetentionSnapshot = {
    weekStart,
    generatedAt: new Date().toISOString(),
    studyDayCount: observation.participant.studyDayCount,
    returnDayCount: observation.participant.returnDayCount,
    reflectionCount: observation.participant.reflectionCount,
    oldEntryRevisits: observation.automated.oldEntryRevisits,
    revisitToReflection: observation.automated.revisitToReflectionLinks,
    followupsStarted: observation.automated.followupsStarted,
    followupsCompleted: observation.automated.followupsCompleted,
    bookmarks: observation.automated.bookmarks,
    copiedMoments: observation.automated.copiedMoments,
    day7Returns: observation.automated.day7Returns,
  };

  const existing = readWeeklySnapshotsRaw().filter((row) => row.weekStart !== weekStart);
  writeWeeklySnapshotsRaw([...existing, snapshot]);
  return snapshot;
}

export function readWeeklyRetentionSnapshots(): WeeklyRetentionSnapshot[] {
  return readWeeklySnapshotsRaw().sort((a, b) => a.weekStart.localeCompare(b.weekStart));
}

export function buildCallbackSurvivalSummary(): CallbackSurvivalSummaryRow[] {
  const report = buildCallbackQualityReviewReport(getAllEntries());
  return sortByEmotionalSurvival(report.items)
    .slice(0, 24)
    .map((item) => ({
      id: item.id,
      text: item.text,
      survivalScore: item.survival.emotionalSurvivalScore,
      residueScore: item.emotionalResidueScore,
      shown: item.survival.callbackShownCount,
      remembered24h: item.survival.remembered24hFlag || item.survival.remembered24hManual,
      remembered72h: item.survival.remembered72hFlag || item.survival.remembered72hManual,
      pruningAction: getCallbackPruningAction(item.id) ?? undefined,
    }));
}

export function buildRevisitConversionSummary(): RevisitConversionSummary {
  const loops = buildRetentionLoopReport();
  const events = loops.events;
  const memoryNoteClicks = events.filter((row) => row.kind === "resurfaced_memory_clicked").length;
  const oldEntryOpens = events.filter((row) => row.kind === "old_entry_opened_from_note").length;
  const revisits = events.filter((row) => row.kind === "entry_revisited").length;
  const followupsStarted = events.filter((row) => row.kind === "followup_recording_started").length;
  const followupsCompleted = events.filter(
    (row) => row.kind === "followup_recording_completed",
  ).length;
  const revisitToReflection = loops.revisitsCausingReflections.filter(
    (row) => row.reflectionEntryId,
  ).length;

  return {
    memoryNoteClicks,
    oldEntryOpens,
    revisits,
    followupsStarted,
    followupsCompleted,
    revisitToReflection,
    conversionRate: pct(revisitToReflection, Math.max(1, revisits)),
  };
}

export function buildEmotionalResidueSummary(): EmotionalResidueSummaryRow[] {
  const manual = readManualStudyNotes().map((note) => ({
    id: note.id,
    source: "manual_note" as const,
    text:
      note.rememberedSentence48h ||
      note.userQuote ||
      note.payReason ||
      "(empty note)",
    feltRemembered: note.feltRemembered,
    feltGeneric: note.feltGeneric,
    wouldPay: note.wouldPay,
    at: note.createdAt,
  }));

  const callbacks = buildCallbackQualityReviewReport(getAllEntries())
    .items.filter((item) => item.emotionalResidueScore >= 50 || item.doubleDown)
    .slice(0, 12)
    .map((item) => ({
      id: item.id,
      source: "callback" as const,
      text: item.text,
      at: item.sourceLocation.file,
    }));

  return [...manual, ...callbacks].sort(
    (a, b) => new Date(b.at).getTime() - new Date(a.at).getTime(),
  );
}

export async function buildObservationSummariesExport(): Promise<ObservationSummariesExport> {
  await captureWeeklyRetentionSnapshot();

  return {
    exportedAt: new Date().toISOString(),
    weeklySnapshots: readWeeklyRetentionSnapshots(),
    callbackSurvival: buildCallbackSurvivalSummary(),
    revisitConversion: buildRevisitConversionSummary(),
    emotionalResidue: buildEmotionalResidueSummary(),
  };
}

export function downloadObservationSummariesJson(payload: ObservationSummariesExport): void {
  if (!isBrowser()) return;

  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `observation-summaries-${payload.exportedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function formatStudyWeekLabel(weekStart: string): string {
  const anchor = getStudyAnchorDay();
  return `Week from ${weekStart} · study anchor ${anchor}`;
}
