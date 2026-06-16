import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { readEvolvingUnderstandingState } from "@/lib/metrics/evolving-understanding-events";

export const ARCHIVE_AS_PRODUCT_EVENT_NAMES = {
  archiveHomeOpened: "archive_product_home_opened",
  postFiveFirstSurface: "post_five_first_surface_open",
  reflectionSixMovementSeen: "reflection_six_archive_movement_seen",
  voluntaryArchiveReturn: "voluntary_archive_home_return",
} as const;

const POST_FIVE_SESSION_KEY = "voicememory_post_five_first_surface";
const MS_DAY = 24 * 60 * 60 * 1000;

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return sessionStorage;
}

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

function hasRecentPromptedReturn(withinMs: number): boolean {
  const cutoff = Date.now() - withinMs;
  const prompted = new Set([
    "return_trigger_reason",
    "return_expectation_met",
    "theory_notification_opened",
  ]);
  return readLocalEvents().some((e) => {
    if (!prompted.has(e.name)) return false;
    return new Date(e.at).getTime() >= cutoff;
  });
}

export function markPostFiveReflectionMilestone(): void {
  const store = getStorage();
  if (!store) return;
  if (countCompletedReflections() < 5) return;
  if (store.getItem(POST_FIVE_SESSION_KEY)) return;
  store.setItem(POST_FIVE_SESSION_KEY, "pending");
}

export function trackArchiveProductHomeOpened(): void {
  trackLocalEvent(ARCHIVE_AS_PRODUCT_EVENT_NAMES.archiveHomeOpened, {});
  maybeTrackPostFiveFirstSurface("archive_belief");
  maybeTrackVoluntaryArchiveHomeReturn();
}

export function trackDiscoverProductOpened(): void {
  maybeTrackPostFiveFirstSurface("discover");
}

function maybeTrackPostFiveFirstSurface(surface: "archive_belief" | "discover"): void {
  const store = getStorage();
  if (!store) return;
  if (countCompletedReflections() < 5) return;

  const flag = store.getItem(POST_FIVE_SESSION_KEY);
  if (!flag) {
    store.setItem(POST_FIVE_SESSION_KEY, "pending");
    return;
  }
  if (flag !== "pending") return;

  store.setItem(POST_FIVE_SESSION_KEY, surface);
  trackLocalEvent(ARCHIVE_AS_PRODUCT_EVENT_NAMES.postFiveFirstSurface, { surface });
}

export function trackReflectionSixArchiveMovementSeen(): void {
  if (countCompletedReflections() < 6) return;
  const events = readLocalEvents();
  const already = events.some((e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.reflectionSixMovementSeen);
  if (already) return;
  trackLocalEvent(ARCHIVE_AS_PRODUCT_EVENT_NAMES.reflectionSixMovementSeen, {});
}

function maybeTrackVoluntaryArchiveHomeReturn(): void {
  if (countCompletedReflections() < 5) return;

  const state = readEvolvingUnderstandingState();
  if (!state.firstWorkingTheorySeenAt) return;

  const hoursSince =
    (Date.now() - new Date(state.firstWorkingTheorySeenAt).getTime()) / (60 * 60 * 1000);
  if (hoursSince < 24) return;

  if (hasRecentPromptedReturn(2 * 60 * 60 * 1000)) return;

  const events = readLocalEvents();
  if (events.some((e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.voluntaryArchiveReturn)) {
    return;
  }

  trackLocalEvent(ARCHIVE_AS_PRODUCT_EVENT_NAMES.voluntaryArchiveReturn, {});
}

export function readPostFiveFirstSurfaceCounts(): {
  archiveFirst: number;
  discoverFirst: number;
  total: number;
} {
  const events = readLocalEvents().filter(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.postFiveFirstSurface,
  );
  const archiveFirst = events.filter((e) => e.meta?.surface === "archive_belief").length;
  const discoverFirst = events.filter((e) => e.meta?.surface === "discover").length;
  return { archiveFirst, discoverFirst, total: events.length };
}

export function clearArchiveAsProductEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(ARCHIVE_AS_PRODUCT_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
  sessionStorage?.removeItem(POST_FIVE_SESSION_KEY);
}
