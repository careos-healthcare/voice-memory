import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  callbackInteractionSignals,
  summarizeCallbackRetention,
} from "@/lib/callback-interaction-signals";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import {
  buildRetentionLoopReport,
  readRetentionLoopEvents,
  type RetentionLoopEvent,
} from "@/lib/retention/retention-loops";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type CallbackNoteKind =
  | "revisit"
  | "resurface"
  | "knows_me"
  | "then_vs_now"
  | "continuation"
  | "change"
  | "familiarity"
  | "recovery"
  | "other";

export interface CallbackLoopMetrics {
  noteId: string;
  noteText: string;
  noteKind: CallbackNoteKind;
  surfaces: number;
  ignores: number;
  revisits: number;
  reflections: number;
  bookmarks: number;
  copies: number;
  followupStarted: number;
  followupCompleted: number;
  day7Returns: number;
  dwellMs: number;
  halfLifeScore: number;
  residueScore: number;
  continuationScore: number;
  loopWeight: number;
  dead: boolean;
}

export interface FollowupContinuationRow {
  promptId: string;
  noteId: string;
  noteText: string;
  started: number;
  completed: number;
  conversionRate: string;
  continuationScore: number;
}

export interface RevisitReflectionSessionRow {
  entryId: string;
  revisitedAt: string;
  sources: string;
  noteId?: string;
  noteText?: string;
  reflectionEntryId?: string;
  converted: boolean;
}

export interface NoteTypeReturnRow {
  kind: CallbackNoteKind;
  revisitCount: number;
  reflectionCount: number;
  bookmarkCount: number;
}

export interface LoopOptimizationReport {
  topPerforming: CallbackLoopMetrics[];
  deadCallbacks: CallbackLoopMetrics[];
  causingRevisits: CallbackLoopMetrics[];
  causingReflections: CallbackLoopMetrics[];
  causingBookmarks: CallbackLoopMetrics[];
  topCopied: CallbackLoopMetrics[];
  topContinuationPrompts: FollowupContinuationRow[];
  revisitSessionsWithReflection: RevisitReflectionSessionRow[];
  noteTypesCausingReturn: NoteTypeReturnRow[];
  avgHalfLife: number;
  avgResidue: number;
  avgContinuationConversion: string;
  hasData: boolean;
}

export const LOOP_HALF_LIFE_DAYS = 14;
export const LOOP_DEAD_SURFACE_MIN = 3;
export const LOOP_DEAD_HALF_LIFE_MAX = 22;
export const LOOP_ACTION_BOOST_MAX = 28;
export const LOOP_IGNORE_PENALTY_MAX = 32;
export const LOOP_DEAD_PENALTY = 36;

function noteLabel(noteId: string, noteText?: string): string {
  if (noteText?.trim()) return noteText.trim();
  return noteId;
}

export function classifyCallbackNoteKind(noteId: string): CallbackNoteKind {
  if (noteId.startsWith("revisit-")) return "revisit";
  if (noteId.startsWith("resurface-") || noteId.startsWith("fam-resurface-")) return "resurface";
  if (noteId.startsWith("knows-me-")) return "knows_me";
  if (noteId.startsWith("tvn-")) return "then_vs_now";
  if (noteId.startsWith("continuation-")) return "continuation";
  if (noteId.startsWith("change-") || noteId.startsWith("moment-")) return "change";
  if (noteId.startsWith("familiarity-")) return "familiarity";
  if (noteId.startsWith("recovery-")) return "recovery";
  return "other";
}

function lastEventAt(events: RetentionLoopEvent[], noteId: string, kinds: string[]): number {
  let latest = 0;
  for (const event of events) {
    if (event.noteId !== noteId) continue;
    if (kinds.length > 0 && !kinds.includes(event.kind)) continue;
    const at = new Date(event.at).getTime();
    if (at > latest) latest = at;
  }
  return latest;
}

/** Decay score — surfaces without action lose weight over time. */
export function callbackHalfLifeScore(input: {
  surfaces: number;
  actions: number;
  daysSinceLastSurface: number;
  daysSinceLastAction: number;
}): number {
  const { surfaces, actions, daysSinceLastSurface, daysSinceLastAction } = input;
  if (surfaces <= 0 && actions <= 0) return 50;

  const actionRatio = (actions + 1) / (surfaces + 1);
  let score = Math.round(actionRatio * 72);

  if (actions > 0 && daysSinceLastAction <= 7) score += 12;
  if (surfaces >= 2 && actions === 0) {
    score -= Math.min(24, Math.round(daysSinceLastSurface / 2));
  }
  if (daysSinceLastSurface > LOOP_HALF_LIFE_DAYS && actions === 0) {
    score -= Math.min(30, Math.round((daysSinceLastSurface - LOOP_HALF_LIFE_DAYS) / 2));
  }

  return Math.max(0, Math.min(100, score));
}

/** How long a callback keeps emotional pull after action or dwell. */
export function emotionalResidueScore(input: {
  bookmarks: number;
  copies: number;
  revisits: number;
  reflections: number;
  day7Returns: number;
  dwellMs: number;
  followupCompleted: number;
}): number {
  let score = 0;
  score += input.bookmarks * 18;
  score += input.copies * 16;
  score += input.revisits * 12;
  score += input.reflections * 22;
  score += input.day7Returns * 14;
  score += input.followupCompleted * 20;
  if (input.dwellMs >= 12_000) score += 10;
  else if (input.dwellMs >= 6_000) score += 6;
  return Math.min(100, score);
}

/** Follow-up prompt conversion — started → completed recording. */
export function continuationConversionScore(started: number, completed: number): number {
  if (started <= 0) return completed > 0 ? 80 : 0;
  const rate = completed / started;
  return Math.round(rate * 100);
}

function aggregateNoteMetrics(
  noteId: string,
  noteText: string,
  events: RetentionLoopEvent[],
): Omit<CallbackLoopMetrics, "halfLifeScore" | "residueScore" | "continuationScore" | "loopWeight" | "dead"> {
  const retention = summarizeCallbackRetention(noteId);

  let revisits = 0;
  let reflections = 0;
  let bookmarks = 0;
  let copies = 0;
  let followupStarted = 0;
  let followupCompleted = 0;
  let day7Returns = 0;

  for (const event of events) {
    if (event.noteId !== noteId) continue;
    if (event.kind === "resurfaced_memory_clicked" || event.kind === "old_entry_opened_from_note") {
      revisits += 1;
    }
    if (event.kind === "followup_recording_completed") reflections += 1;
    if (event.kind === "bookmark_created") bookmarks += 1;
    if (event.kind === "copied_memory_moment") copies += 1;
    if (event.kind === "followup_recording_started") followupStarted += 1;
    if (event.kind === "followup_recording_completed") followupCompleted += 1;
    if (event.kind === "returned_within_7_days") day7Returns += 1;
  }

  const signals = callbackInteractionSignals(noteId, []);
  const dwellMs = Math.max(signals.dwellMs, retention.reread > 0 ? 4000 : 0);

  return {
    noteId,
    noteText,
    noteKind: classifyCallbackNoteKind(noteId),
    surfaces: retention.surfaced,
    ignores: retention.ignored,
    revisits: Math.max(revisits, retention.revisit),
    reflections,
    bookmarks: Math.max(bookmarks, retention.bookmark),
    copies: Math.max(copies, retention.copied),
    followupStarted,
    followupCompleted: Math.max(followupCompleted, retention.recording),
    day7Returns,
    dwellMs,
  };
}

function finalizeMetrics(
  base: Omit<CallbackLoopMetrics, "halfLifeScore" | "residueScore" | "continuationScore" | "loopWeight" | "dead">,
  events: RetentionLoopEvent[],
): CallbackLoopMetrics {
  const today = toDayKey(new Date().toISOString());
  const lastSurfaceMs = lastEventAt(events, base.noteId, []);
  const actionKinds = [
    "bookmark_created",
    "copied_memory_moment",
    "old_entry_opened_from_note",
    "resurfaced_memory_clicked",
    "followup_recording_completed",
    "returned_within_7_days",
  ];
  const lastActionMs = lastEventAt(events, base.noteId, actionKinds);

  const daysSinceLastSurface =
    lastSurfaceMs > 0
      ? daysBetweenKeys(toDayKey(new Date(lastSurfaceMs).toISOString()), today)
      : LOOP_HALF_LIFE_DAYS;

  const daysSinceLastAction =
    lastActionMs > 0
      ? daysBetweenKeys(toDayKey(new Date(lastActionMs).toISOString()), today)
      : daysSinceLastSurface;

  const actions =
    base.bookmarks +
    base.copies +
    base.revisits +
    base.reflections +
    base.followupCompleted +
    base.day7Returns;

  const halfLifeScore = callbackHalfLifeScore({
    surfaces: base.surfaces,
    actions,
    daysSinceLastSurface,
    daysSinceLastAction,
  });

  const residueScore = emotionalResidueScore({
    bookmarks: base.bookmarks,
    copies: base.copies,
    revisits: base.revisits,
    reflections: base.reflections,
    day7Returns: base.day7Returns,
    dwellMs: base.dwellMs,
    followupCompleted: base.followupCompleted,
  });

  const continuationScore = continuationConversionScore(
    base.followupStarted,
    base.followupCompleted,
  );

  const dead =
    base.surfaces >= LOOP_DEAD_SURFACE_MIN &&
    actions === 0 &&
    halfLifeScore <= LOOP_DEAD_HALF_LIFE_MAX;

  const loopWeight = computeLoopWeight({
    surfaces: base.surfaces,
    ignores: base.ignores,
    residueScore,
    halfLifeScore,
    continuationScore,
    actions,
    dwellMs: base.dwellMs,
    dead,
  });

  return {
    ...base,
    halfLifeScore,
    residueScore,
    continuationScore,
    loopWeight,
    dead,
  };
}

function computeLoopWeight(input: {
  surfaces: number;
  ignores: number;
  residueScore: number;
  halfLifeScore: number;
  continuationScore: number;
  actions: number;
  dwellMs: number;
  dead: boolean;
}): number {
  let weight = 0;

  if (input.actions > 0) {
    weight += Math.min(LOOP_ACTION_BOOST_MAX, 8 + input.actions * 4);
  }
  if (input.residueScore >= 40) {
    weight += Math.round(input.residueScore * 0.22);
  }
  if (input.continuationScore >= 50) {
    weight += Math.round(input.continuationScore * 0.12);
  }
  if (input.dwellMs >= 8_000 && input.actions > 0) {
    weight += 8;
  }

  const ignoreRatio =
    input.surfaces > 0 ? input.ignores / Math.max(1, input.surfaces + input.ignores) : 0;
  if (ignoreRatio >= 0.55) {
    weight -= Math.min(LOOP_IGNORE_PENALTY_MAX, Math.round(ignoreRatio * 36));
  }
  if (input.halfLifeScore < 30) {
    weight -= Math.round((30 - input.halfLifeScore) * 0.6);
  }
  if (input.dead) {
    weight -= LOOP_DEAD_PENALTY;
  }

  return Math.round(weight);
}

function buildMetricsMap(events: RetentionLoopEvent[]): Map<string, CallbackLoopMetrics> {
  const ids = new Map<string, string>();

  for (const event of events) {
    if (event.noteId) ids.set(event.noteId, noteLabel(event.noteId, event.noteText));
  }

  const map = new Map<string, CallbackLoopMetrics>();
  for (const [noteId, noteText] of ids) {
    const base = aggregateNoteMetrics(noteId, noteText, events);
    map.set(noteId, finalizeMetrics(base, events));
  }

  return map;
}

function buildFollowupRows(events: RetentionLoopEvent[]): FollowupContinuationRow[] {
  const byPrompt = new Map<string, FollowupContinuationRow>();

  for (const event of events) {
    if (event.kind !== "followup_recording_started" && event.kind !== "followup_recording_completed") {
      continue;
    }
    const promptId = event.promptId ?? event.noteId ?? "unknown";
    const noteId = event.noteId ?? promptId;
    const row =
      byPrompt.get(promptId) ??
      ({
        promptId,
        noteId,
        noteText: noteLabel(noteId, event.noteText),
        started: 0,
        completed: 0,
        conversionRate: "—",
        continuationScore: 0,
      } satisfies FollowupContinuationRow);

    if (event.kind === "followup_recording_started") row.started += 1;
    if (event.kind === "followup_recording_completed") row.completed += 1;
    byPrompt.set(promptId, row);
  }

  return [...byPrompt.values()]
    .map((row) => {
      const score = continuationConversionScore(row.started, row.completed);
      return {
        ...row,
        continuationScore: score,
        conversionRate: row.started > 0 ? `${score}%` : row.completed > 0 ? "100%" : "—",
      };
    })
    .sort((a, b) => b.continuationScore - a.continuationScore || b.completed - a.completed);
}

function buildNoteTypeRows(metrics: CallbackLoopMetrics[]): NoteTypeReturnRow[] {
  const map = new Map<CallbackNoteKind, NoteTypeReturnRow>();

  for (const row of metrics) {
    const existing =
      map.get(row.noteKind) ??
      ({
        kind: row.noteKind,
        revisitCount: 0,
        reflectionCount: 0,
        bookmarkCount: 0,
      } satisfies NoteTypeReturnRow);
    existing.revisitCount += row.revisits;
    existing.reflectionCount += row.reflections;
    existing.bookmarkCount += row.bookmarks;
    map.set(row.noteKind, existing);
  }

  return [...map.values()].sort(
    (a, b) =>
      b.revisitCount + b.reflectionCount * 2 - (a.revisitCount + a.reflectionCount * 2),
  );
}

function buildRevisitSessions(
  loopReport: ReturnType<typeof buildRetentionLoopReport>,
): RevisitReflectionSessionRow[] {
  return loopReport.revisitsCausingReflections.map((row) => ({
    entryId: row.entryId,
    revisitedAt: row.revisitedAt,
    sources: row.sources,
    noteId: row.noteId,
    noteText: row.noteId ? undefined : undefined,
    reflectionEntryId: row.reflectionEntryId,
    converted: Boolean(row.reflectionEntryId),
  }));
}

/** Full loop optimization report — debug only. */
export function buildLoopOptimizationReport(_entries: JournalEntry[]): LoopOptimizationReport {
  const events = readRetentionLoopEvents();
  const loopReport = buildRetentionLoopReport();
  const metricsMap = buildMetricsMap(events);
  const all = [...metricsMap.values()];

  const topPerforming = [...all]
    .filter((row) => !row.dead)
    .sort(
      (a, b) =>
        b.loopWeight + b.residueScore - (a.loopWeight + a.residueScore) ||
        b.halfLifeScore - a.halfLifeScore,
    )
    .slice(0, 12);

  const deadCallbacks = all.filter((row) => row.dead).sort((a, b) => a.halfLifeScore - b.halfLifeScore);

  const causingRevisits = [...all]
    .filter((row) => row.revisits > 0)
    .sort((a, b) => b.revisits - a.revisits)
    .slice(0, 12);

  const causingReflections = [...all]
    .filter((row) => row.reflections > 0 || row.followupCompleted > 0)
    .sort((a, b) => b.reflections + b.followupCompleted - (a.reflections + a.followupCompleted))
    .slice(0, 12);

  const causingBookmarks = [...all]
    .filter((row) => row.bookmarks > 0)
    .sort((a, b) => b.bookmarks - a.bookmarks)
    .slice(0, 12);

  const topCopied = [...all]
    .filter((row) => row.copies > 0)
    .sort((a, b) => b.copies - a.copies)
    .slice(0, 12);

  const topContinuationPrompts = buildFollowupRows(events).slice(0, 10);
  const revisitSessionsWithReflection = buildRevisitSessions(loopReport);
  const noteTypesCausingReturn = buildNoteTypeRows(all);

  const avgHalfLife =
    all.length > 0 ? Math.round(all.reduce((sum, row) => sum + row.halfLifeScore, 0) / all.length) : 0;
  const avgResidue =
    all.length > 0 ? Math.round(all.reduce((sum, row) => sum + row.residueScore, 0) / all.length) : 0;

  const totalStarted = topContinuationPrompts.reduce((sum, row) => sum + row.started, 0);
  const totalCompleted = topContinuationPrompts.reduce((sum, row) => sum + row.completed, 0);
  const avgContinuationConversion =
    totalStarted > 0 ? `${continuationConversionScore(totalStarted, totalCompleted)}%` : "—";

  return {
    topPerforming,
    deadCallbacks,
    causingRevisits,
    causingReflections,
    causingBookmarks,
    topCopied,
    topContinuationPrompts,
    revisitSessionsWithReflection,
    noteTypesCausingReturn,
    avgHalfLife,
    avgResidue,
    avgContinuationConversion,
    hasData: events.length > 0 || all.length > 0,
  };
}

export function loopMetricsForNote(noteId: string, noteText?: string): CallbackLoopMetrics | null {
  const events = readRetentionLoopEvents();
  const base = aggregateNoteMetrics(noteId, noteLabel(noteId, noteText), events);
  if (
    base.surfaces === 0 &&
    base.revisits === 0 &&
    base.bookmarks === 0 &&
    base.copies === 0 &&
    base.followupStarted === 0
  ) {
    return null;
  }
  return finalizeMetrics(base, events);
}

/** Adaptive surfacing weight — action callbacks rise, ignored/dead callbacks decay. */
export function applyLoopOptimizationBoost(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  const metrics = loopMetricsForNote(note.id, note.text);
  if (!metrics) return baseScore;

  let score = baseScore + metrics.loopWeight;

  if (metrics.dead) return Math.max(0, score - LOOP_DEAD_PENALTY);
  if (metrics.residueScore >= 50) score += Math.round(metrics.residueScore * 0.08);
  if (metrics.halfLifeScore >= 65) score += 6;

  const linked = linkedEntriesForNote(note, entries);
  const linkedDwell = linked.reduce((sum, entry) => {
    const signals = callbackInteractionSignals(note.id, [entry.id]);
    return sum + signals.dwellMs;
  }, 0);
  if (linkedDwell >= 10_000 && metrics.loopWeight > 0) score += 5;

  return Math.max(0, Math.round(score));
}

export function continuationBoostForNote(noteId: string): number {
  const metrics = loopMetricsForNote(noteId);
  if (!metrics) return 0;
  if (metrics.continuationScore <= 0) return 0;
  return Math.round(metrics.continuationScore * 0.35);
}

export function rankNotesByLoopOptimization(
  notes: MemoryNote[],
  entries: JournalEntry[],
): MemoryNote[] {
  return [...notes].sort((a, b) => {
    const aScore = applyLoopOptimizationBoost(a, entries, a.confidence);
    const bScore = applyLoopOptimizationBoost(b, entries, b.confidence);
    return bScore - aScore || b.confidence - a.confidence;
  });
}

export function formatLoopOptimizationSummary(report: LoopOptimizationReport): string {
  return `${report.topPerforming.length} active · ${report.deadCallbacks.length} dead · conversion ${report.avgContinuationConversion}`;
}
