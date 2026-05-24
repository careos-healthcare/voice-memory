import { trackLocalEvent, readLocalEvents } from "@/lib/local-analytics";

export const FIRST_SESSION_REVISIT_UNDERSTOOD = "first_session_revisit_understood";
export const FIRST_SESSION_OLD_REFLECTION_OPENED = "first_session_old_reflection_opened";
export const FIRST_SESSION_AUDIO_REPLAYED = "first_session_audio_replayed";
export const FIRST_SESSION_RETURN_AFTER_REVISIT = "first_session_return_after_revisit";
export const FIRST_SESSION_CONFUSION = "first_session_confusion";

const FIRST_SESSION_KEY = "voicememory_first_session_comprehension";
const FIRST_REVISIT_AT_KEY = "voicememory_first_revisit_at";

interface FirstSessionState {
  firstReflectionAt?: string;
  firstRevisitAt?: string;
  revisitUnderstood?: boolean;
  oldReflectionOpened?: boolean;
  audioReplayed?: boolean;
  returnedAfterRevisit?: boolean;
  confusionCount: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readState(): FirstSessionState {
  if (!isBrowser()) return { confusionCount: 0 };
  try {
    const raw = localStorage.getItem(FIRST_SESSION_KEY);
    if (!raw) return { confusionCount: 0 };
    const parsed = JSON.parse(raw) as FirstSessionState;
    return { ...parsed, confusionCount: parsed.confusionCount ?? 0 };
  } catch {
    return { confusionCount: 0 };
  }
}

function writeState(state: FirstSessionState): void {
  if (!isBrowser()) return;
  localStorage.setItem(FIRST_SESSION_KEY, JSON.stringify(state));
}

function markFirstReflectionIfNeeded(): void {
  const state = readState();
  if (state.firstReflectionAt) return;
  writeState({ ...state, firstReflectionAt: new Date().toISOString() });
}

export function isWithinFirstSessionWindow(): boolean {
  const state = readState();
  const anchor = state.firstReflectionAt ?? state.firstRevisitAt;
  if (!anchor) return true;
  const days = (Date.now() - new Date(anchor).getTime()) / (1000 * 60 * 60 * 24);
  return days <= 7;
}

export function trackFirstSessionRevisitUnderstood(source = "memory_link"): void {
  markFirstReflectionIfNeeded();
  const state = readState();
  if (state.revisitUnderstood) return;
  writeState({ ...state, revisitUnderstood: true });
  trackLocalEvent(FIRST_SESSION_REVISIT_UNDERSTOOD, { source });
}

export function trackFirstSessionOldReflectionOpened(entryId: string, source = "revisit_link"): void {
  markFirstReflectionIfNeeded();
  const state = readState();
  const now = new Date().toISOString();
  if (!state.firstRevisitAt) {
    localStorage.setItem(FIRST_REVISIT_AT_KEY, now);
  }
  if (!state.oldReflectionOpened) {
    writeState({
      ...state,
      oldReflectionOpened: true,
      firstRevisitAt: state.firstRevisitAt ?? now,
    });
    trackLocalEvent(FIRST_SESSION_OLD_REFLECTION_OPENED, { entryId, source });
  }
  if (!state.revisitUnderstood) {
    trackFirstSessionRevisitUnderstood(source);
  }
}

export function trackFirstSessionAudioReplayed(entryId: string, clip: string): void {
  markFirstReflectionIfNeeded();
  const state = readState();
  if (state.audioReplayed) return;
  writeState({ ...state, audioReplayed: true });
  trackLocalEvent(FIRST_SESSION_AUDIO_REPLAYED, { entryId, clip });
}

export function trackFirstSessionConfusion(context: string, detail = ""): void {
  markFirstReflectionIfNeeded();
  const state = readState();
  writeState({ ...state, confusionCount: state.confusionCount + 1 });
  trackLocalEvent(FIRST_SESSION_CONFUSION, { context, detail: detail.slice(0, 120) });
}

/** Call on home/app load — logs return within 7 days of first revisit. */
export function maybeTrackFirstSessionReturnAfterRevisit(): void {
  const state = readState();
  if (!state.firstRevisitAt || state.returnedAfterRevisit) return;
  const hours =
    (Date.now() - new Date(state.firstRevisitAt).getTime()) / (1000 * 60 * 60);
  if (hours < 1 || hours > 24 * 7) return;
  writeState({ ...state, returnedAfterRevisit: true });
  trackLocalEvent(FIRST_SESSION_RETURN_AFTER_REVISIT, {
    hoursSinceFirstRevisit: String(Math.round(hours)),
  });
}

export function readFirstSessionComprehensionSummary() {
  const state = readState();
  const events = readLocalEvents().filter((event) => event.name.startsWith("first_session_"));
  return {
    ...state,
    eventCount: events.length,
    events: events.slice(-20),
    withinFirstSessionWindow: isWithinFirstSessionWindow(),
  };
}

export function markFirstReflectionCreated(): void {
  markFirstReflectionIfNeeded();
}
