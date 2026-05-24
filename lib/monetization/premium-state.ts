import { readWillingnessFounderLabels } from "@/lib/research/willingness-signals";
import { getOrCreateParticipantId } from "@/lib/research/retention-observation";
import { detectArchiveValueMoments } from "@/lib/monetization/archive-value";
import type { PremiumState, PremiumStateRecord } from "@/types/monetization-validation";

const STATE_KEY = "voicememory_premium_state";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readRecord(): PremiumStateRecord {
  if (!isBrowser()) {
    return { state: "free", updatedAt: new Date().toISOString(), source: "behavior" };
  }
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return { state: "free", updatedAt: new Date().toISOString(), source: "behavior" };
    return JSON.parse(raw) as PremiumStateRecord;
  } catch {
    return { state: "free", updatedAt: new Date().toISOString(), source: "behavior" };
  }
}

function writeRecord(record: PremiumStateRecord): void {
  if (!isBrowser()) return;
  localStorage.setItem(STATE_KEY, JSON.stringify(record));
}

function stateFromFounderLabels(): PremiumState | null {
  const labels = readWillingnessFounderLabels(getOrCreateParticipantId());
  const latest = labels[0];
  if (!latest) return null;
  if (latest.label === "would_pay") return "willing_to_pay_observed";
  if (latest.label === "maybe") return "interested";
  if (latest.label === "unlikely") return "free";
  return null;
}

function stateFromBehavior(): PremiumState {
  const moments = detectArchiveValueMoments();
  const strong = moments.filter((row) => row.strength >= 70);
  const moderate = moments.filter((row) => row.strength >= 55);

  if (strong.length >= 3 || moments.some((row) => row.kind === "would_miss_archive")) {
    return "willing_to_pay_observed";
  }
  if (strong.length >= 2 || moderate.length >= 3) {
    return "interested";
  }
  if (moments.length >= 1) {
    return "considering";
  }
  return "free";
}

/** Refresh premium state from observed behavior (never forces upsells). */
export function refreshPremiumStateFromBehavior(): PremiumStateRecord {
  const founder = stateFromFounderLabels();
  const current = readRecord();

  if (current.source === "founder" && founder) {
    const record: PremiumStateRecord = {
      state: founder,
      updatedAt: new Date().toISOString(),
      source: "founder",
    };
    writeRecord(record);
    return record;
  }

  const behavior = stateFromBehavior();
  const nextState =
    current.source === "founder"
      ? maxState(current.state, behavior)
      : founder ?? behavior;

  const record: PremiumStateRecord = {
    state: nextState,
    updatedAt: new Date().toISOString(),
    source: founder ? "founder" : "behavior",
  };
  writeRecord(record);
  return record;
}

function maxState(a: PremiumState, b: PremiumState): PremiumState {
  const order: PremiumState[] = [
    "free",
    "considering",
    "interested",
    "willing_to_pay_observed",
  ];
  return order.indexOf(a) >= order.indexOf(b) ? a : b;
}

export function getPremiumState(): PremiumState {
  return refreshPremiumStateFromBehavior().state;
}

export function getPremiumStateRecord(): PremiumStateRecord {
  return refreshPremiumStateFromBehavior();
}

/** Manual founder override — debug / study only. */
export function setFounderPremiumState(state: PremiumState): PremiumStateRecord {
  const record: PremiumStateRecord = {
    state,
    updatedAt: new Date().toISOString(),
    source: "founder",
  };
  writeRecord(record);
  return record;
}

export function premiumStateLabel(state: PremiumState): string {
  const labels: Record<PremiumState, string> = {
    free: "Free",
    considering: "Considering",
    interested: "Interested",
    willing_to_pay_observed: "Willing-to-pay observed",
  };
  return labels[state];
}
