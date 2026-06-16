import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";
import { getCurrentTierId, isProTier } from "@/lib/entitlement/entitlements";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ValueMomentPaywallStorage,
  ValueMomentPaywallSurface,
  ValueMomentState,
} from "@/types/value-moment-paywall";

export const VALUE_MOMENT_STORAGE_KEY = "voicememory_value_moment_paywall";
export const VALUE_MOMENT_REFLECTION_TARGET = BLIND_SPOT_MIN_REFLECTIONS;

const EMPTY_STORAGE: ValueMomentPaywallStorage = {
  hasSeenFirstBlindSpot: false,
  hasSeenFirstDiscover: false,
  postBlindSpotPaywallSeen: false,
  postDiscoverPaywallSeen: false,
  blindSpotsVisitCount: 0,
  discoverVisitCount: 0,
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readStorage(): ValueMomentPaywallStorage {
  if (!isBrowser()) return { ...EMPTY_STORAGE };
  try {
    const raw = localStorage.getItem(VALUE_MOMENT_STORAGE_KEY);
    if (!raw) return { ...EMPTY_STORAGE };
    const parsed = JSON.parse(raw) as Partial<ValueMomentPaywallStorage>;
    return {
      hasSeenFirstBlindSpot: Boolean(parsed.hasSeenFirstBlindSpot),
      hasSeenFirstDiscover: Boolean(parsed.hasSeenFirstDiscover),
      postBlindSpotPaywallSeen: Boolean(parsed.postBlindSpotPaywallSeen),
      postDiscoverPaywallSeen: Boolean(parsed.postDiscoverPaywallSeen),
      blindSpotsVisitCount: Number(parsed.blindSpotsVisitCount) || 0,
      discoverVisitCount: Number(parsed.discoverVisitCount) || 0,
    };
  } catch {
    return { ...EMPTY_STORAGE };
  }
}

function writeStorage(next: ValueMomentPaywallStorage): void {
  if (!isBrowser()) return;
  localStorage.setItem(VALUE_MOMENT_STORAGE_KEY, JSON.stringify(next));
}

export function countValueMomentReflections(entries: JournalEntry[]): number {
  return entries.filter((e) => e.reflectionPending !== true).length;
}

/** Founder debug flag — same key as billing-state founder Pro preview. */
export function isFounderPreviewUser(): boolean {
  if (!isBrowser()) return false;
  try {
    return localStorage.getItem("voicememory_founder_pro_preview") === "1";
  } catch {
    return false;
  }
}

/** Pro (paid or local preview), and explicit founder preview never see value-moment paywalls. */
export function shouldBypassValueMomentPaywall(): boolean {
  if (!isBrowser()) return true;
  if (isFounderPreviewUser()) return true;
  if (getCurrentTierId() === "pro" || isProTier()) return true;
  return false;
}

export function readValueMomentState(entriesInput?: JournalEntry[]): ValueMomentState {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const reflectionCount = countValueMomentReflections(entries);
  const stored = readStorage();
  const hasReachedFiveReflections = reflectionCount >= VALUE_MOMENT_REFLECTION_TARGET;
  const bypass = shouldBypassValueMomentPaywall();

  const shouldShowPostBlindSpotPaywall =
    !bypass &&
    hasReachedFiveReflections &&
    stored.hasSeenFirstBlindSpot &&
    stored.blindSpotsVisitCount >= 2 &&
    !stored.postBlindSpotPaywallSeen;

  const shouldShowPostDiscoverPaywall =
    !bypass &&
    stored.hasSeenFirstDiscover &&
    stored.discoverVisitCount >= 2 &&
    !stored.postDiscoverPaywallSeen;

  const freeValueUsed =
    stored.hasSeenFirstBlindSpot &&
    stored.hasSeenFirstDiscover &&
    stored.postBlindSpotPaywallSeen &&
    stored.postDiscoverPaywallSeen;

  const shouldGateArchiveContinuity = !bypass && freeValueUsed;

  let reason = "within_free_value_window";
  if (bypass) reason = "pro_or_founder_preview";
  else if (shouldShowPostBlindSpotPaywall) reason = "post_blind_spot_value";
  else if (shouldShowPostDiscoverPaywall) reason = "post_discover_value";
  else if (shouldGateArchiveContinuity) reason = "archive_continuity";
  else if (!stored.hasSeenFirstBlindSpot) reason = "first_blind_spot_pending";
  else if (!stored.hasSeenFirstDiscover) reason = "first_discover_pending";
  else if (!hasReachedFiveReflections) reason = "under_five_reflections";

  return {
    reflectionCount,
    hasSeenFirstBlindSpot: stored.hasSeenFirstBlindSpot,
    hasSeenFirstDiscover: stored.hasSeenFirstDiscover,
    hasReachedFiveReflections,
    shouldShowPostBlindSpotPaywall,
    shouldShowPostDiscoverPaywall,
    shouldGateArchiveContinuity,
    freeValueUsed,
    reason,
  };
}

export function markFirstBlindSpotSeen(): void {
  const stored = readStorage();
  if (stored.hasSeenFirstBlindSpot) return;
  writeStorage({ ...stored, hasSeenFirstBlindSpot: true });
}

export function markFirstDiscoverSeen(): void {
  const stored = readStorage();
  if (stored.hasSeenFirstDiscover) return;
  writeStorage({ ...stored, hasSeenFirstDiscover: true });
}

export function markPostBlindSpotPaywallSeen(): void {
  const stored = readStorage();
  writeStorage({ ...stored, postBlindSpotPaywallSeen: true });
}

export function markPostDiscoverPaywallSeen(): void {
  const stored = readStorage();
  writeStorage({ ...stored, postDiscoverPaywallSeen: true });
}

export function recordBlindSpotsPageVisit(): number {
  const stored = readStorage();
  const blindSpotsVisitCount = stored.blindSpotsVisitCount + 1;
  writeStorage({ ...stored, blindSpotsVisitCount });
  return blindSpotsVisitCount;
}

export function recordDiscoverPageVisit(): number {
  const stored = readStorage();
  const discoverVisitCount = stored.discoverVisitCount + 1;
  writeStorage({ ...stored, discoverVisitCount });
  return discoverVisitCount;
}

export function shouldShowValueMomentPaywall(
  surface: ValueMomentPaywallSurface,
  entriesInput?: JournalEntry[],
): boolean {
  const state = readValueMomentState(entriesInput);
  switch (surface) {
    case "blind_spot":
      return state.shouldShowPostBlindSpotPaywall;
    case "discover":
      return state.shouldShowPostDiscoverPaywall;
    case "archive_continuity":
      return state.shouldGateArchiveContinuity;
    default:
      return false;
  }
}

export function resetValueMomentPaywallForTests(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(VALUE_MOMENT_STORAGE_KEY);
}
