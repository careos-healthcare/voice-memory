import { toDayKey } from "@/lib/dates";
import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { RoundupLineCandidate } from "@/types/roundup-quality-review";
import type { ReflectiveRoundupLine, ReflectiveRoundupSignal } from "@/types/reflective-roundup";
import type { RoundupReturnWindow } from "@/types/roundup-observation";

export const ROUNDUP_OPENED = "roundup_opened";
export const ROUNDUP_LINE_PAUSED = "roundup_line_paused_on";
export const ROUNDUP_LINE_COPIED = "roundup_line_copied";
export const ROUNDUP_LINE_BOOKMARKED = "roundup_line_bookmarked";
export const ROUNDUP_CONTINUE_CLICKED = "roundup_continue_clicked";
export const ROUNDUP_INTENTION_SAVED = "roundup_intention_saved";
export const ROUNDUP_ITEM_REVISITED = "roundup_item_revisited";
/** @deprecated Use roundup_item_revisited */
export const ROUNDUP_RELATED_ENTRY_OPENED = "roundup_related_entry_opened";
export const ROUNDUP_FOLLOWUP_RECORDED = "roundup_followup_recorded";
export const ROUNDUP_RETURN_AFTER = "roundup_return_after_roundup";
export const ROUNDUP_INSTANT_ABANDON = "roundup_instant_abandon";

const SHOWN_LINES_KEY = "voicememory_roundup_shown_lines";
const LAST_OPEN_KEY = "voicememory_roundup_last_open";
const ACTIVE_CONTEXT_KEY = "voicememory_roundup_active_context";
const SESSION_KEY = "voicememory_roundup_session";
const MAX_SHOWN_LINES = 160;
const INSTANT_ABANDON_MS = 8000;
const PAUSE_DWELL_MS = 1200;
const CONTEXT_TTL_MS = 45 * 60 * 1000;

export const ROUNDUP_IGNORE_RATIO_THRESHOLD = 0.72;
export const ROUNDUP_IGNORE_MIN_EXPOSURES = 3;
export const ROUNDUP_REVISIT_REFLECTION_BOOST = 14;
export const ROUNDUP_IGNORE_PENALTY = 18;
export const ROUNDUP_REPEAT_WORDING_PENALTY = 999;

interface RoundupShownLine {
  textKey: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug: string;
  shownAt: string;
}

interface RoundupSession {
  periodSlug: string;
  openedAt: string;
  hadAction: boolean;
}

interface RoundupActiveContext {
  itemId: string;
  entryId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug: string;
  at: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function normalizeLineKey(text: string): string {
  return text.trim().replace(/\s+/g, " ").toLowerCase().slice(0, 96);
}

function lineMeta(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  entryId?: string;
  intentionId?: string;
  dwellMs?: string;
  window?: RoundupReturnWindow;
}): Record<string, string> {
  return {
    itemId: input.itemId,
    lineKey: normalizeLineKey(input.text),
    text: input.text.slice(0, 120),
    signal: input.signal,
    periodSlug: input.periodSlug ?? "",
    ...(input.entryId ? { entryId: input.entryId } : {}),
    ...(input.intentionId ? { intentionId: input.intentionId } : {}),
    ...(input.dwellMs ? { dwellMs: input.dwellMs } : {}),
    ...(input.window ? { window: input.window } : {}),
  };
}

function readShownLines(): RoundupShownLine[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(SHOWN_LINES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as RoundupShownLine[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeShownLines(rows: RoundupShownLine[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(SHOWN_LINES_KEY, JSON.stringify(rows.slice(-MAX_SHOWN_LINES)));
}

function readSession(): RoundupSession | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as RoundupSession) : null;
  } catch {
    return null;
  }
}

function writeSession(session: RoundupSession | null): void {
  if (!isBrowser()) return;
  if (!session) {
    sessionStorage.removeItem(SESSION_KEY);
    return;
  }
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

function markSessionAction(): void {
  const session = readSession();
  if (!session || session.hadAction) return;
  writeSession({ ...session, hadAction: true });
}

function noteReturnAfterRoundup(periodSlug: string): void {
  const lastOpenRaw = localStorage.getItem(LAST_OPEN_KEY);
  if (!lastOpenRaw) return;

  try {
    const last = JSON.parse(lastOpenRaw) as { at: string; periodSlug: string };
    const hours =
      (Date.now() - new Date(last.at).getTime()) / (1000 * 60 * 60);
    if (hours <= 0) return;

    if (hours <= 24) {
      trackLocalEvent(
        ROUNDUP_RETURN_AFTER,
        lineMeta({
          itemId: `return-${periodSlug}`,
          text: last.periodSlug,
          signal: "returned",
          periodSlug,
          window: "24h",
        }),
      );
    } else if (hours <= 24 * 7) {
      trackLocalEvent(
        ROUNDUP_RETURN_AFTER,
        lineMeta({
          itemId: `return-${periodSlug}`,
          text: last.periodSlug,
          signal: "returned",
          periodSlug,
          window: "7d",
        }),
      );
    }
  } catch {
    // ignore malformed state
  }
}

export function trackRoundupOpened(periodSlug: string): void {
  noteReturnAfterRoundup(periodSlug);
  trackLocalEvent(ROUNDUP_OPENED, { periodSlug });
  writeSession({ periodSlug, openedAt: new Date().toISOString(), hadAction: false });
  localStorage.setItem(
    LAST_OPEN_KEY,
    JSON.stringify({ periodSlug, at: new Date().toISOString() }),
  );
}

export function closeRoundupSession(): void {
  const session = readSession();
  if (!session) return;

  const dwellMs = Date.now() - new Date(session.openedAt).getTime();
  if (!session.hadAction && dwellMs < INSTANT_ABANDON_MS) {
    trackLocalEvent(ROUNDUP_INSTANT_ABANDON, {
      periodSlug: session.periodSlug,
      dwellMs: String(dwellMs),
    });
  }
  writeSession(null);
}

export function recordRoundupLinesShown(
  periodSlug: string,
  lines: Pick<ReflectiveRoundupLine, "text" | "signal">[],
): void {
  if (!isBrowser() || lines.length === 0) return;
  const now = new Date().toISOString();
  const existing = readShownLines();
  const next = [...existing];

  for (const line of lines) {
    next.push({
      textKey: normalizeLineKey(line.text),
      text: line.text,
      signal: line.signal,
      periodSlug,
      shownAt: now,
    });
  }
  writeShownLines(next);
}

export function trackRoundupLinePausedOn(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  dwellMs: number;
}): void {
  if (input.dwellMs < PAUSE_DWELL_MS) return;
  markSessionAction();
  trackLocalEvent(
    ROUNDUP_LINE_PAUSED,
    lineMeta({ ...input, dwellMs: String(input.dwellMs) }),
  );
}

export function trackRoundupLineCopied(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
}): void {
  markSessionAction();
  trackLocalEvent(ROUNDUP_LINE_COPIED, lineMeta(input));
}

export function trackRoundupLineBookmarked(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  entryId: string;
}): void {
  markSessionAction();
  trackLocalEvent(ROUNDUP_LINE_BOOKMARKED, lineMeta(input));
}

export function trackRoundupContinueClicked(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  kind?: string;
}): void {
  markSessionAction();
  trackLocalEvent(ROUNDUP_CONTINUE_CLICKED, {
    ...lineMeta(input),
    kind: input.kind ?? "",
  });
}

export function trackRoundupIntentionSaved(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  intentionId: string;
  kind?: string;
}): void {
  markSessionAction();
  trackLocalEvent(ROUNDUP_INTENTION_SAVED, {
    ...lineMeta(input),
    intentionId: input.intentionId,
    kind: input.kind ?? "",
  });
}

export function trackRoundupItemRevisited(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  entryId: string;
  kind?: string;
}): void {
  markSessionAction();
  storeRoundupActiveContext(input);
  trackLocalEvent(ROUNDUP_ITEM_REVISITED, {
    ...lineMeta(input),
    entryId: input.entryId,
    kind: input.kind ?? "",
  });
}

/** @deprecated Use trackRoundupItemRevisited */
export function trackRoundupRelatedEntryOpened(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  entryId: string;
  kind?: string;
}): void {
  trackRoundupItemRevisited(input);
}

export function trackRoundupIntentionLinkOpened(input: {
  itemId: string;
  text: string;
  intentionId: string;
  periodSlug?: string;
}): void {
  markSessionAction();
  trackLocalEvent("roundup_intention_link_opened", {
    itemId: input.itemId,
    intentionId: input.intentionId,
    text: input.text.slice(0, 120),
    periodSlug: input.periodSlug ?? "",
    lineKey: normalizeLineKey(input.text),
    signal: "returned",
  });
}

export function trackRoundupFollowupRecorded(input: {
  itemId: string;
  text: string;
  entryId: string;
  periodSlug?: string;
}): void {
  markSessionAction();
  trackLocalEvent(
    ROUNDUP_FOLLOWUP_RECORDED,
    lineMeta({ ...input, signal: "returned" }),
  );
}

function storeRoundupActiveContext(input: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  entryId: string;
}): void {
  if (!isBrowser()) return;
  const context: RoundupActiveContext = {
    itemId: input.itemId,
    entryId: input.entryId,
    text: input.text,
    signal: input.signal,
    periodSlug: input.periodSlug ?? "",
    at: new Date().toISOString(),
  };
  sessionStorage.setItem(ACTIVE_CONTEXT_KEY, JSON.stringify(context));
}

export function maybeTrackRoundupBookmark(entryId: string): void {
  if (!isBrowser()) return;
  try {
    const raw = sessionStorage.getItem(ACTIVE_CONTEXT_KEY);
    if (!raw) return;
    const context = JSON.parse(raw) as RoundupActiveContext;
    if (context.entryId !== entryId) return;
    if (Date.now() - new Date(context.at).getTime() > CONTEXT_TTL_MS) return;
    trackRoundupLineBookmarked({
      itemId: context.itemId,
      text: context.text,
      signal: context.signal,
      periodSlug: context.periodSlug,
      entryId,
    });
  } catch {
    // ignore
  }
}

export function maybeTrackRoundupFollowupRecorded(
  noteId: string | undefined,
  entryId: string,
): void {
  if (!noteId?.startsWith("roundup-")) return;
  const itemId = noteId.slice("roundup-".length);
  trackRoundupFollowupRecorded({
    itemId,
    text: itemId,
    entryId,
  });
}

export function isRepeatedRoundupWording(text: string, withinDays = 21): boolean {
  const key = normalizeLineKey(text);
  const cutoffDay = toDayKey(new Date(Date.now() - withinDays * 86400000));

  return readShownLines().some((row) => {
    if (row.textKey !== key) return false;
    return row.shownAt.slice(0, 10) >= cutoffDay;
  });
}

interface AggregatedLineMetrics {
  lineKey: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  pauses: number;
  copies: number;
  bookmarks: number;
  continues: number;
  intentionsSaved: number;
  relatedEntryOpens: number;
  followupsRecorded: number;
  pauseDwellMs: number;
}

function aggregateLineMetrics(): Map<string, AggregatedLineMetrics> {
  const rows = new Map<string, AggregatedLineMetrics>();

  const ensure = (
    lineKey: string,
    text: string,
    signal: ReflectiveRoundupSignal,
  ): AggregatedLineMetrics => {
    const existing = rows.get(lineKey);
    if (existing) return existing;
    const created: AggregatedLineMetrics = {
      lineKey,
      text,
      signal,
      pauses: 0,
      copies: 0,
      bookmarks: 0,
      continues: 0,
      intentionsSaved: 0,
      relatedEntryOpens: 0,
      followupsRecorded: 0,
      pauseDwellMs: 0,
    };
    rows.set(lineKey, created);
    return created;
  };

  for (const event of readLocalEvents()) {
    const meta = event.meta;
    if (!meta?.lineKey) continue;
    const row = ensure(
      meta.lineKey,
      meta.text ?? meta.lineKey,
      (meta.signal as ReflectiveRoundupSignal) ?? "returned",
    );

    switch (event.name) {
      case ROUNDUP_LINE_PAUSED:
        row.pauses += 1;
        row.pauseDwellMs += Number(meta.dwellMs ?? 0);
        break;
      case ROUNDUP_LINE_COPIED:
        row.copies += 1;
        break;
      case ROUNDUP_LINE_BOOKMARKED:
        row.bookmarks += 1;
        break;
      case ROUNDUP_CONTINUE_CLICKED:
        row.continues += 1;
        break;
      case ROUNDUP_INTENTION_SAVED:
        row.intentionsSaved += 1;
        break;
      case ROUNDUP_ITEM_REVISITED:
      case ROUNDUP_RELATED_ENTRY_OPENED:
        row.relatedEntryOpens += 1;
        break;
      case ROUNDUP_FOLLOWUP_RECORDED:
        row.followupsRecorded += 1;
        break;
      default:
        break;
    }
  }

  return rows;
}

function lineContinuationScore(row: AggregatedLineMetrics): number {
  return (
    row.continues * 4 +
    row.followupsRecorded * 6 +
    row.intentionsSaved * 3 +
    row.relatedEntryOpens * 2 +
    row.bookmarks * 2 +
    row.copies * 2
  );
}

function lineIgnoreRatio(row: AggregatedLineMetrics): number {
  const exposures = row.pauses + row.relatedEntryOpens;
  if (exposures < ROUNDUP_IGNORE_MIN_EXPOSURES) return 0;
  const actions =
    row.continues +
    row.followupsRecorded +
    row.bookmarks +
    row.copies +
    row.intentionsSaved;
  if (actions === 0) return 1;
  return Math.max(0, 1 - actions / exposures);
}

export function tuneRoundupCandidateScore(candidate: RoundupLineCandidate): number {
  let score = candidate.score;

  if (isRepeatedRoundupWording(candidate.text)) {
    return candidate.score - ROUNDUP_REPEAT_WORDING_PENALTY;
  }

  const metrics = aggregateLineMetrics().get(normalizeLineKey(candidate.text));
  if (!metrics) return score;

  const ignoreRatio = lineIgnoreRatio(metrics);
  if (ignoreRatio >= ROUNDUP_IGNORE_RATIO_THRESHOLD) {
    score -= ROUNDUP_IGNORE_PENALTY;
  }

  if (metrics.relatedEntryOpens > 0 && metrics.followupsRecorded > 0) {
    score += ROUNDUP_REVISIT_REFLECTION_BOOST;
  } else if (metrics.relatedEntryOpens > 0 && metrics.continues > 0) {
    score += Math.round(ROUNDUP_REVISIT_REFLECTION_BOOST * 0.6);
  }

  return score;
}

export function applyObservationScoreAdjustments(
  candidates: RoundupLineCandidate[],
): RoundupLineCandidate[] {
  return candidates
    .map((candidate) => ({
      ...candidate,
      score: tuneRoundupCandidateScore(candidate),
    }))
    .filter((candidate) => candidate.score > 0);
}

export function readRoundupEvents() {
  return readLocalEvents().filter((event) => event.name.startsWith("roundup_"));
}

export function countRoundupEvent(name: string): number {
  return readLocalEvents().filter((event) => event.name === name).length;
}

export function hasRoundupReflectionAfterRevisit(lineKey: string): boolean {
  const metrics = aggregateLineMetrics().get(lineKey);
  if (!metrics) return false;
  return metrics.relatedEntryOpens > 0 && metrics.followupsRecorded > 0;
}

export { aggregateLineMetrics, lineContinuationScore, lineIgnoreRatio, normalizeLineKey };
