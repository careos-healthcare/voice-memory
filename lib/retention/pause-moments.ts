import { readRetentionLoopEvents, type RetentionLoopEvent } from "@/lib/retention/retention-loops";

export type PauseMomentKind =
  | "callback_shown"
  | "dwell_after_callback"
  | "scroll_pause"
  | "audio_replay"
  | "old_entry_revisit"
  | "bookmark_after_callback"
  | "copy_after_callback"
  | "follow_up_after_callback";

export interface PauseMomentEvent {
  id: string;
  callbackId: string;
  kind: PauseMomentKind;
  at: string;
  dwellMs?: number;
  scrollPauseMs?: number;
  surface?: string;
  meta?: Record<string, string>;
}

export interface PauseMomentScores {
  pauseScore: number;
  emotionalInterruptionScore: number;
  rereadLikelihood: number;
  replayLikelihood: number;
}

export interface CallbackPauseAnalysis extends PauseMomentScores {
  dwellAfterCallbackMs: number;
  scrollPauseCount: number;
  scrollPauseTotalMs: number;
  audioReplayCount: number;
  oldEntryRevisitCount: number;
  bookmarkCount: number;
  copyCount: number;
  followUpCount: number;
  actionCount: number;
  highDwellLowAction: boolean;
  causedAudioReplay: boolean;
  causedOldEntryRevisit: boolean;
}

export interface PauseMomentRankedRow {
  callbackId: string;
  pauseScore: number;
  emotionalInterruptionScore: number;
  dwellAfterCallbackMs: number;
  eventCount: number;
}

const PAUSE_KEY = "voicememory_pause_moments";
const ACTIVE_CALLBACK_KEY = "voicememory_pause_active_callback";
const MAX_EVENTS = 800;
const SCROLL_PAUSE_MS = 1200;
const MIN_DWELL_MS = 500;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readEvents(): PauseMomentEvent[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(PAUSE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as PauseMomentEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEvents(events: PauseMomentEvent[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(PAUSE_KEY, JSON.stringify(events.slice(-MAX_EVENTS)));
}

function pushEvent(event: Omit<PauseMomentEvent, "id" | "at">): void {
  if (!isBrowser()) return;
  const events = readEvents();
  events.push({
    ...event,
    id: `pause-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    at: new Date().toISOString(),
  });
  writeEvents(events);
}

function resolveCallbackId(explicit?: string): string | null {
  if (explicit) return explicit;
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(ACTIVE_CALLBACK_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { callbackId?: string };
    return parsed.callbackId ?? null;
  } catch {
    return null;
  }
}

/** Remember which callback line is on screen — internal only. */
export function rememberCallbackPauseContext(callbackId: string, surface?: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(
    ACTIVE_CALLBACK_KEY,
    JSON.stringify({ callbackId, surface, shownAt: Date.now() }),
  );
}

export function resolveCallbackPauseContext(): {
  callbackId: string;
  surface?: string;
  shownAt: number;
} | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(ACTIVE_CALLBACK_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as {
      callbackId?: string;
      surface?: string;
      shownAt?: number;
    };
    if (!parsed.callbackId) return null;
    return {
      callbackId: parsed.callbackId,
      surface: parsed.surface,
      shownAt: parsed.shownAt ?? Date.now(),
    };
  } catch {
    return null;
  }
}

export function trackCallbackShown(callbackId: string, surface?: string): void {
  rememberCallbackPauseContext(callbackId, surface);
  pushEvent({ callbackId, kind: "callback_shown", surface });
}

export function trackDwellAfterCallback(
  callbackId: string,
  dwellMs: number,
  surface?: string,
): void {
  if (dwellMs < MIN_DWELL_MS) return;
  pushEvent({
    callbackId,
    kind: "dwell_after_callback",
    dwellMs: Math.round(dwellMs),
    surface,
  });
}

export function trackDwellForActiveCallback(dwellMs: number, surface?: string): void {
  const callbackId = resolveCallbackId();
  if (!callbackId) return;
  trackDwellAfterCallback(callbackId, dwellMs, surface);
}

export function trackScrollPauseNearCallback(
  callbackId: string,
  scrollPauseMs: number,
  surface?: string,
): void {
  if (scrollPauseMs < SCROLL_PAUSE_MS) return;
  pushEvent({
    callbackId,
    kind: "scroll_pause",
    scrollPauseMs: Math.round(scrollPauseMs),
    surface,
  });
}

export function trackAudioReplayAfterCallback(
  callbackId?: string,
  clip?: "then" | "now",
  surface?: string,
): void {
  const resolved = resolveCallbackId(callbackId);
  if (!resolved) return;
  pushEvent({
    callbackId: resolved,
    kind: "audio_replay",
    surface,
    meta: clip ? { clip } : undefined,
  });
}

export function trackOldEntryRevisitAfterCallback(
  callbackId?: string,
  entryId?: string,
  surface?: string,
): void {
  const resolved = resolveCallbackId(callbackId);
  if (!resolved) return;
  pushEvent({
    callbackId: resolved,
    kind: "old_entry_revisit",
    surface,
    meta: entryId ? { entryId } : undefined,
  });
}

export function trackBookmarkAfterCallback(
  callbackId?: string,
  bookmarkType?: string,
  surface?: string,
): void {
  const resolved = resolveCallbackId(callbackId);
  if (!resolved) return;
  pushEvent({
    callbackId: resolved,
    kind: "bookmark_after_callback",
    surface,
    meta: bookmarkType ? { bookmarkType } : undefined,
  });
}

export function trackCopyAfterCallback(
  callbackId?: string,
  sourceId?: string,
  surface?: string,
): void {
  const resolved = resolveCallbackId(callbackId);
  if (!resolved) return;
  pushEvent({
    callbackId: resolved,
    kind: "copy_after_callback",
    surface,
    meta: sourceId ? { sourceId } : undefined,
  });
}

export function trackFollowUpAfterCallback(
  callbackId?: string,
  promptId?: string,
  surface?: string,
): void {
  const resolved = resolveCallbackId(callbackId ?? undefined);
  if (!resolved) return;
  pushEvent({
    callbackId: resolved,
    kind: "follow_up_after_callback",
    surface,
    meta: promptId ? { promptId } : undefined,
  });
}

export function readPauseMomentEvents(callbackId?: string): PauseMomentEvent[] {
  const events = readEvents();
  if (!callbackId) return events;
  return events.filter((row) => row.callbackId === callbackId);
}

function countKind(events: PauseMomentEvent[], kind: PauseMomentKind): number {
  return events.filter((row) => row.kind === kind).length;
}

function sumDwell(events: PauseMomentEvent[]): number {
  return events
    .filter((row) => row.kind === "dwell_after_callback")
    .reduce((sum, row) => sum + (row.dwellMs ?? 0), 0);
}

function sumScrollPause(events: PauseMomentEvent[]): number {
  return events
    .filter((row) => row.kind === "scroll_pause")
    .reduce((sum, row) => sum + (row.scrollPauseMs ?? 0), 0);
}

function loopRevisitCount(callbackId: string, noteKeys: string[]): number {
  return readRetentionLoopEvents().filter(
    (event) =>
      event.kind === "old_entry_opened_from_note" &&
      (event.noteId === callbackId || noteKeys.includes(event.noteId ?? "")),
  ).length;
}

/** Bind scroll pause + in-view dwell to a memory line element — internal only. */
export function bindMemoryLinePauseTracking(
  element: HTMLElement,
  callbackId: string,
  surface?: string,
): () => void {
  if (!isBrowser()) return () => undefined;

  rememberCallbackPauseContext(callbackId, surface);

  let visibleSince: number | null = null;
  let lastScrollAt = Date.now();
  let scrollPauseTimer: ReturnType<typeof setTimeout> | null = null;
  let accumulatedDwell = 0;
  let lastScrollPauseAt = 0;

  const observer = new IntersectionObserver(
    (entries) => {
      const entry = entries[0];
      if (entry?.isIntersecting) {
        if (visibleSince === null) visibleSince = Date.now();
      } else if (visibleSince !== null) {
        accumulatedDwell += Date.now() - visibleSince;
        visibleSince = null;
      }
    },
    { threshold: 0.55 },
  );

  const onScroll = () => {
    lastScrollAt = Date.now();
    if (scrollPauseTimer) clearTimeout(scrollPauseTimer);
    scrollPauseTimer = setTimeout(() => {
      if (visibleSince === null) return;
      const pauseMs = Date.now() - lastScrollAt;
      if (pauseMs >= SCROLL_PAUSE_MS && Date.now() - lastScrollPauseAt > SCROLL_PAUSE_MS) {
        lastScrollPauseAt = Date.now();
        trackScrollPauseNearCallback(callbackId, pauseMs, surface);
      }
    }, SCROLL_PAUSE_MS);
  };

  observer.observe(element);
  window.addEventListener("scroll", onScroll, { passive: true });

  return () => {
    observer.disconnect();
    window.removeEventListener("scroll", onScroll);
    if (scrollPauseTimer) clearTimeout(scrollPauseTimer);
    if (visibleSince !== null) {
      accumulatedDwell += Date.now() - visibleSince;
    }
    if (accumulatedDwell >= MIN_DWELL_MS) {
      trackDwellAfterCallback(callbackId, accumulatedDwell, surface);
    }
  };
}

export function computeCallbackPauseAnalysis(
  callbackId: string,
  noteKeys: string[] = [],
): CallbackPauseAnalysis {
  const events = readPauseMomentEvents(callbackId);
  const dwellAfterCallbackMs = sumDwell(events);
  const scrollPauseCount = countKind(events, "scroll_pause");
  const scrollPauseTotalMs = sumScrollPause(events);
  const audioReplayCount = countKind(events, "audio_replay");
  const oldEntryRevisitCount = Math.max(
    countKind(events, "old_entry_revisit"),
    loopRevisitCount(callbackId, noteKeys),
  );
  const bookmarkCount = countKind(events, "bookmark_after_callback");
  const copyCount = countKind(events, "copy_after_callback");
  const followUpCount = countKind(events, "follow_up_after_callback");

  const actionCount =
    audioReplayCount +
    oldEntryRevisitCount +
    bookmarkCount +
    copyCount +
    followUpCount;

  const pauseScore = Math.min(
    100,
    Math.round(
      dwellAfterCallbackMs / 55 +
        scrollPauseTotalMs / 45 +
        scrollPauseCount * 10 +
        actionCount * 8,
    ),
  );

  const emotionalInterruptionScore = Math.min(
    100,
    Math.round(
      scrollPauseCount * 16 +
        pauseScore * 0.35 +
        (dwellAfterCallbackMs > 8000 ? 22 : dwellAfterCallbackMs > 4000 ? 12 : 0),
    ),
  );

  const rereadLikelihood = Math.min(
    100,
    Math.round(
      scrollPauseCount * 14 +
        dwellAfterCallbackMs / 65 +
        oldEntryRevisitCount * 20 +
        bookmarkCount * 12,
    ),
  );

  const replayLikelihood = Math.min(
    100,
    Math.round(audioReplayCount * 38 + dwellAfterCallbackMs / 90 + scrollPauseCount * 6),
  );

  const highDwellLowAction = dwellAfterCallbackMs >= 6000 && actionCount === 0;

  return {
    pauseScore,
    emotionalInterruptionScore,
    rereadLikelihood,
    replayLikelihood,
    dwellAfterCallbackMs,
    scrollPauseCount,
    scrollPauseTotalMs,
    audioReplayCount,
    oldEntryRevisitCount,
    bookmarkCount,
    copyCount,
    followUpCount,
    actionCount,
    highDwellLowAction,
    causedAudioReplay: audioReplayCount > 0,
    causedOldEntryRevisit: oldEntryRevisitCount > 0,
  };
}

export function rankCallbacksByPauseScore(
  callbackIds: string[],
): PauseMomentRankedRow[] {
  return callbackIds
    .map((callbackId) => {
      const analysis = computeCallbackPauseAnalysis(callbackId);
      const events = readPauseMomentEvents(callbackId);
      return {
        callbackId,
        pauseScore: analysis.pauseScore,
        emotionalInterruptionScore: analysis.emotionalInterruptionScore,
        dwellAfterCallbackMs: analysis.dwellAfterCallbackMs,
        eventCount: events.length,
      };
    })
    .sort((a, b) => b.pauseScore - a.pauseScore || b.eventCount - a.eventCount);
}

export function clearPauseMomentEvents(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PAUSE_KEY);
  sessionStorage.removeItem(ACTIVE_CALLBACK_KEY);
}
