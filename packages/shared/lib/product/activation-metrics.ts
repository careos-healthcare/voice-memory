import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readBlindSpotAnalyticsEvents } from "@/lib/blind-spots/blind-spot-events";
import {
  countLocalEvents,
  hasLocalEvent,
  LAUNCH_EVENTS,
  readLocalEvents,
  trackLocalEvent,
} from "@/lib/local-analytics";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { readAllTheoryEvents } from "@/lib/theories/theory-events";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import type { BlindSpotReaction } from "@/types/blind-spot";
import type { TheoryFeedbackReaction } from "@/types/theory";

export const ACTIVATION_METRIC_EVENTS = {
  fiveReflectionsReached: "activation_five_reflections_reached",
  discoverySurfaceOpened: "activation_discovery_surface_opened",
  strongInsightReaction: "activation_strong_insight_reaction",
} as const;

const STRONG_BLIND_SPOT: BlindSpotReaction[] = ["surprising", "uncomfortably_accurate"];
const STRONG_THEORY: TheoryFeedbackReaction[] = ["surprising"];

export interface ActivationMetricsReport {
  generatedAt: string;
  reflectionCreators: number;
  fiveReflectionsReached: number;
  fiveReflectionsRate: number | null;
  discoverySurfaceOpens: number;
  discoveryOpenRate: number | null;
  strongInsightReactions: number;
  strongReactionRate: number | null;
  currentReflectionCount: number;
  hasReachedFiveLocally: boolean;
  lines: string[];
}

function countEventsNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

export function observeActivationReflectionCount(reflectionCount?: number): void {
  const count = reflectionCount ?? countCompletedReflections();
  if (count >= 5 && !hasLocalEvent(ACTIVATION_METRIC_EVENTS.fiveReflectionsReached)) {
    trackLocalEvent(ACTIVATION_METRIC_EVENTS.fiveReflectionsReached, {
      reflectionCount: String(count),
    });
  }
}

export function trackActivationDiscoverySurface(
  surface: "discover" | "blind_spots",
): void {
  trackLocalEvent(ACTIVATION_METRIC_EVENTS.discoverySurfaceOpened, { surface });
}

export function trackActivationStrongInsightReaction(input: {
  surface: "blind_spot" | "theory";
  reaction: string;
}): void {
  trackLocalEvent(ACTIVATION_METRIC_EVENTS.strongInsightReaction, {
    surface: input.surface,
    reaction: input.reaction,
  });
}

export function observeStrongReactionFromBlindSpot(reaction: BlindSpotReaction): void {
  if (!STRONG_BLIND_SPOT.includes(reaction)) return;
  trackActivationStrongInsightReaction({ surface: "blind_spot", reaction });
}

export function observeStrongReactionFromTheory(reaction: TheoryFeedbackReaction): void {
  if (!STRONG_THEORY.includes(reaction)) return;
  trackActivationStrongInsightReaction({ surface: "theory", reaction });
}

export function buildActivationMetricsReport(): ActivationMetricsReport {
  const reflectionCreators = Math.max(
    countLocalEvents(LAUNCH_EVENTS.firstReflectionCreated),
    countCompletedReflections() > 0 ? 1 : 0,
  );
  const denom = Math.max(1, reflectionCreators);

  const fiveReflectionsReached = Math.max(
    countEventsNamed(ACTIVATION_METRIC_EVENTS.fiveReflectionsReached),
    countCompletedReflections() >= 5 ? 1 : 0,
  );
  const discoverySurfaceOpens = Math.max(
    countEventsNamed(ACTIVATION_METRIC_EVENTS.discoverySurfaceOpened),
    readAllTheoryEvents().filter((e) => e.name === "discover_opened").length > 0 ? 1 : 0,
    readBlindSpotAnalyticsEvents().filter((e) => e.name === "blind_spot_opened").length > 0
      ? 1
      : 0,
  );
  const strongFromEvents = countEventsNamed(
    ACTIVATION_METRIC_EVENTS.strongInsightReaction,
  );
  const strongFromFeedback =
    readAllBlindSpotFeedback().filter((r) => STRONG_BLIND_SPOT.includes(r.reaction)).length +
    readAllTheoryFeedback().filter((r) => STRONG_THEORY.includes(r.reaction)).length;
  const strongInsightReactions = Math.max(strongFromEvents, strongFromFeedback);

  const fiveReflectionsRate = Math.round((fiveReflectionsReached / denom) * 1000) / 10;
  const discoveryOpenRate = Math.round((discoverySurfaceOpens / denom) * 1000) / 10;
  const strongReactionRate = Math.round((strongInsightReactions / denom) * 1000) / 10;

  const currentReflectionCount = countCompletedReflections();

  const lines = [
    `Reached 5 reflections: ${fiveReflectionsRate}% (${fiveReflectionsReached} / ${denom} creators on this device).`,
    `Opened Discover or Blind spots: ${discoveryOpenRate}% (${discoverySurfaceOpens} / ${denom}).`,
    `Surprising or Uncomfortably Accurate reaction: ${strongReactionRate}% (${strongInsightReactions} / ${denom}).`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    reflectionCreators: denom,
    fiveReflectionsReached,
    fiveReflectionsRate,
    discoverySurfaceOpens,
    discoveryOpenRate,
    strongInsightReactions,
    strongReactionRate,
    currentReflectionCount,
    hasReachedFiveLocally: currentReflectionCount >= 5,
    lines,
  };
}

export function clearActivationMetricsForEval(): void {
  if (typeof globalThis.localStorage === "undefined") return;
  const store = globalThis.localStorage;
  const key = "voicememory_local_events";
  try {
    const raw = store.getItem(key);
    if (!raw) return;
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter(
      (e) =>
        !Object.values(ACTIVATION_METRIC_EVENTS).includes(
          e.name as (typeof ACTIVATION_METRIC_EVENTS)[keyof typeof ACTIVATION_METRIC_EVENTS],
        ),
    );
    store.setItem(key, JSON.stringify(filtered));
  } catch {
    // ignore
  }
}
