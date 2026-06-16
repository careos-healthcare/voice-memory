import { readValueMomentState } from "@/lib/billing/value-moment-paywall";
import type {
  EvolvingUnderstandingEvent,
  EvolvingUnderstandingEventName,
  EvolvingUnderstandingState,
} from "@/types/evolving-understanding";

export const EVOLVING_UNDERSTANDING_EVENTS_KEY =
  "voicememory_evolving_understanding_events";
export const EVOLVING_UNDERSTANDING_STATE_KEY =
  "voicememory_evolving_understanding_state";

const MS_HOUR = 60 * 60 * 1000;
export const RETURN_TO_CHECK_ARCHIVE_HOURS = 24;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readState(): EvolvingUnderstandingState {
  const store = getStorage();
  if (!store) {
    return { firstWorkingTheorySeenAt: null, returnedToCheckArchiveViewTracked: false };
  }
  try {
    const raw = store.getItem(EVOLVING_UNDERSTANDING_STATE_KEY);
    if (!raw) {
      return { firstWorkingTheorySeenAt: null, returnedToCheckArchiveViewTracked: false };
    }
    const parsed = JSON.parse(raw) as Partial<EvolvingUnderstandingState>;
    return {
      firstWorkingTheorySeenAt:
        typeof parsed.firstWorkingTheorySeenAt === "string"
          ? parsed.firstWorkingTheorySeenAt
          : null,
      returnedToCheckArchiveViewTracked: Boolean(
        parsed.returnedToCheckArchiveViewTracked,
      ),
    };
  } catch {
    return { firstWorkingTheorySeenAt: null, returnedToCheckArchiveViewTracked: false };
  }
}

function writeState(state: EvolvingUnderstandingState): void {
  getStorage()?.setItem(EVOLVING_UNDERSTANDING_STATE_KEY, JSON.stringify(state));
}

function readEvents(): EvolvingUnderstandingEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(EVOLVING_UNDERSTANDING_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as EvolvingUnderstandingEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEvents(events: EvolvingUnderstandingEvent[]): void {
  getStorage()?.setItem(
    EVOLVING_UNDERSTANDING_EVENTS_KEY,
    JSON.stringify(events.slice(-500)),
  );
}

export function readEvolvingUnderstandingEvents(): EvolvingUnderstandingEvent[] {
  return readEvents();
}

export function readEvolvingUnderstandingState(): EvolvingUnderstandingState {
  return readState();
}

export function clearEvolvingUnderstandingForEval(): void {
  const store = getStorage();
  store?.removeItem(EVOLVING_UNDERSTANDING_EVENTS_KEY);
  store?.removeItem(EVOLVING_UNDERSTANDING_STATE_KEY);
}

function hasEvent(name: EvolvingUnderstandingEventName): boolean {
  return readEvents().some((e) => e.name === name);
}

export function trackEvolvingUnderstandingEvent(
  name: EvolvingUnderstandingEventName,
  meta?: Record<string, string | number | boolean>,
): void {
  if (hasEvent(name) && name !== "evolving_view_card_seen") return;
  const events = readEvents();
  events.push({ name, at: new Date().toISOString(), meta });
  writeEvents(events);
}

/** First blind spot review opened — seeds the evolving-understanding loop. */
export function recordFirstWorkingTheorySeen(): void {
  const state = readState();
  if (!state.firstWorkingTheorySeenAt) {
    writeState({
      ...state,
      firstWorkingTheorySeenAt: new Date().toISOString(),
    });
  }
  if (!hasEvent("first_working_theory_seen")) {
    trackEvolvingUnderstandingEvent("first_working_theory_seen");
  }
}

export function trackEvolvingViewCardSeen(surface: string): void {
  const events = readEvents();
  const recent = events.filter((e) => e.name === "evolving_view_card_seen");
  const last = recent[recent.length - 1];
  if (
    last?.meta?.surface === surface &&
    Date.now() - new Date(last.at).getTime() < MS_HOUR
  ) {
    return;
  }
  events.push({
    name: "evolving_view_card_seen",
    at: new Date().toISOString(),
    meta: { surface },
  });
  writeEvents(events);
}

export function trackWhatHappensNextClicked(): void {
  if (hasEvent("what_happens_next_clicked")) return;
  trackEvolvingUnderstandingEvent("what_happens_next_clicked");
}

export function maybeTrackDiscoverAfterFirstBlindSpot(): void {
  if (!readValueMomentState().hasSeenFirstBlindSpot) return;
  if (hasEvent("discover_after_first_blind_spot_opened")) return;
  trackEvolvingUnderstandingEvent("discover_after_first_blind_spot_opened");
}

export function maybeTrackReturnedToCheckArchiveView(
  route: "discover" | "theories",
): void {
  if (!readValueMomentState().hasSeenFirstBlindSpot) return;

  const state = readState();
  if (state.returnedToCheckArchiveViewTracked) return;
  if (!state.firstWorkingTheorySeenAt) return;

  const hoursSince =
    (Date.now() - new Date(state.firstWorkingTheorySeenAt).getTime()) / MS_HOUR;
  if (hoursSince < RETURN_TO_CHECK_ARCHIVE_HOURS) return;

  writeState({ ...state, returnedToCheckArchiveViewTracked: true });
  trackEvolvingUnderstandingEvent("returned_to_check_archive_view", { route });
}
