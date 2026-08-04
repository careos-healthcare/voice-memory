import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ValueMomentPaywallStorage,
  ValueMomentPaywallSurface,
  ValueMomentState,
} from "@/types/value-moment-paywall";

export const VALUE_MOMENT_STORAGE_KEY = "voicememory_value_moment_paywall";
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

/** Web purchase boundaries are retired; subscriptions are store-only on mobile. */
export function shouldBypassValueMomentPaywall(): boolean {
  return true;
}

export function readValueMomentState(
  entriesInput?: JournalEntry[],
): ValueMomentState {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const reflectionCount = countValueMomentReflections(entries);
  const stored = readStorage();
  return {
    reflectionCount,
    hasSeenFirstBlindSpot: stored.hasSeenFirstBlindSpot,
    hasSeenFirstDiscover: stored.hasSeenFirstDiscover,
    hasReachedFiveReflections: false,
    shouldShowPostBlindSpotPaywall: false,
    shouldShowPostDiscoverPaywall: false,
    shouldGateArchiveContinuity: false,
    freeValueUsed: false,
    reason: "web_purchase_retired",
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
  _surface: ValueMomentPaywallSurface,
  _entriesInput?: JournalEntry[],
): boolean {
  void _surface;
  void _entriesInput;
  return false;
}

export function resetValueMomentPaywallForTests(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(VALUE_MOMENT_STORAGE_KEY);
}
