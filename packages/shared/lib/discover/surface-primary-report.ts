import {
  BLIND_SPOT_EVENTS,
  readBlindSpotAnalyticsEvents,
} from "@/lib/blind-spots/blind-spot-events";
import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { averageWowMomentScore } from "@/lib/blind-spots/wow-moment-score";
import { readAllTheoryEvents } from "@/lib/theories/theory-events";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import { readSessionRetentionSnapshot } from "@/lib/retention/session-retention";
import type {
  ProductSurfaceId,
  SurfaceMetricRow,
  SurfacePrimaryReport,
} from "@/types/theory";

const SURFACE_LABELS: Record<ProductSurfaceId, string> = {
  discover: "Discover (theory change feed)",
  blind_spot: "Blind spot review",
  prediction_review: "Prediction review",
  emerging_pattern: "Emerging patterns",
};

function countEvents(name: string): number {
  const blind = readBlindSpotAnalyticsEvents().filter((e) => e.name === name).length;
  const theory = readAllTheoryEvents().filter((e) => e.name === name).length;
  return blind + theory;
}

function blindSpotFeedbackMetrics() {
  const records = readAllBlindSpotFeedback();
  const reactions = records.map((r) => r.reaction);
  const total = reactions.length || 1;
  return {
    surprisingRate: Math.round(
      (reactions.filter((r) => r === "surprising").length / total) * 100,
    ),
    uncomfortablyAccurateRate: Math.round(
      (reactions.filter((r) => r === "uncomfortably_accurate").length / total) * 100,
    ),
    averageWowScore: averageWowMomentScore(reactions),
    feedbackCount: reactions.length,
  };
}

function theoryFeedbackMetrics() {
  const records = readAllTheoryFeedback();
  const total = records.length || 1;
  const surprising = records.filter((r) => r.reaction === "surprising").length;
  return {
    surprisingRate: Math.round((surprising / total) * 100),
    uncomfortablyAccurateRate: 0,
    averageWowScore:
      records.length > 0
        ? Math.round(
            (records.reduce((sum, r) => {
              const weight =
                r.reaction === "surprising"
                  ? 2
                  : r.reaction === "feels_true"
                    ? 1
                    : r.reaction === "not_true"
                      ? -2
                      : r.reaction === "too_obvious"
                        ? -1
                        : 0;
              return sum + weight;
            }, 0) /
              records.length) *
              100,
          ) / 100
        : 0,
    feedbackCount: records.length,
  };
}

function openCountFor(surface: ProductSurfaceId): number {
  switch (surface) {
    case "discover":
      return countEvents("discover_opened");
    case "blind_spot":
      return countEvents(BLIND_SPOT_EVENTS.blindSpotOpened);
    case "prediction_review":
      return (
        countEvents(BLIND_SPOT_EVENTS.predictionReviewOpened) +
        countEvents(BLIND_SPOT_EVENTS.predictionAccuracyOpened)
      );
    case "emerging_pattern":
      return countEvents(BLIND_SPOT_EVENTS.emergingPatternOpened);
    default:
      return 0;
  }
}

function revisitCountFor(surface: ProductSurfaceId): number {
  switch (surface) {
    case "discover":
      return (
        readAllTheoryEvents().filter((e) => e.name === "theory_change_clicked").length +
        readAllTheoryEvents().filter((e) => e.name === "theory_change_expanded").length
      );
    case "blind_spot":
      return readAllBlindSpotFeedback().length;
    case "prediction_review":
      return readBlindSpotAnalyticsEvents().filter(
        (e) =>
          e.name === BLIND_SPOT_EVENTS.predictionReviewOpened ||
          e.name === BLIND_SPOT_EVENTS.predictionAccuracyOpened,
      ).length;
    case "emerging_pattern":
      return readBlindSpotAnalyticsEvents().filter(
        (e) => e.name === BLIND_SPOT_EVENTS.emergingPatternOpened,
      ).length;
    default:
      return 0;
  }
}

function buildSurfaceRow(
  surface: ProductSurfaceId,
  sessionCount: number,
  blindMetrics: ReturnType<typeof blindSpotFeedbackMetrics>,
  theoryMetrics: ReturnType<typeof theoryFeedbackMetrics>,
): SurfaceMetricRow {
  const opens = openCountFor(surface);
  const openRate =
    sessionCount > 0 ? Math.round((opens / sessionCount) * 100) : opens > 0 ? 100 : 0;
  const revisits = revisitCountFor(surface);
  const revisitRate = opens > 0 ? Math.round((revisits / opens) * 100) : 0;

  const useBlind = surface === "blind_spot" || surface === "prediction_review" || surface === "emerging_pattern";
  const metrics = useBlind ? blindMetrics : theoryMetrics;

  let surprisingRate = metrics.surprisingRate;
  let uncomfortablyAccurateRate = metrics.uncomfortablyAccurateRate;
  let averageWowScore = metrics.averageWowScore;

  if (surface === "discover") {
    surprisingRate = theoryMetrics.surprisingRate;
    uncomfortablyAccurateRate = 0;
    averageWowScore = theoryMetrics.averageWowScore;
  }

  if (surface === "blind_spot") {
    surprisingRate = blindMetrics.surprisingRate;
    uncomfortablyAccurateRate = blindMetrics.uncomfortablyAccurateRate;
    averageWowScore = blindMetrics.averageWowScore;
  }

  if (surface === "prediction_review" || surface === "emerging_pattern") {
    surprisingRate = blindMetrics.surprisingRate;
    uncomfortablyAccurateRate = blindMetrics.uncomfortablyAccurateRate;
    averageWowScore = blindMetrics.averageWowScore;
  }

  return {
    surface,
    label: SURFACE_LABELS[surface],
    openCount: opens,
    openRate,
    revisitRate,
    surprisingRate,
    uncomfortablyAccurateRate,
    averageWowScore,
  };
}

function pickHighest(
  surfaces: SurfaceMetricRow[],
  key: keyof Pick<
    SurfaceMetricRow,
    "revisitRate" | "surprisingRate" | "uncomfortablyAccurateRate" | "averageWowScore"
  >,
): ProductSurfaceId | null {
  const sorted = [...surfaces].sort((a, b) => b[key] - a[key]);
  const top = sorted[0];
  if (!top || top[key] <= 0) return null;
  return top.surface;
}

/** Compare discover vs blind spot surfaces for primary-product signals. */
export function buildSurfacePrimaryReport(): SurfacePrimaryReport {
  const snapshot = readSessionRetentionSnapshot();
  const sessionCount = Math.max(snapshot.sessionCount, 1);
  const discoverOpens = countEvents("discover_opened");
  const theoryChangeOpenRate = Math.round((discoverOpens / sessionCount) * 100);

  const blindMetrics = blindSpotFeedbackMetrics();
  const theoryMetrics = theoryFeedbackMetrics();

  const surfaces: SurfaceMetricRow[] = (
    ["discover", "blind_spot", "prediction_review", "emerging_pattern"] as ProductSurfaceId[]
  ).map((surface) => buildSurfaceRow(surface, sessionCount, blindMetrics, theoryMetrics));

  const highestRevisit = pickHighest(surfaces, "revisitRate");
  const highestSurprising = pickHighest(surfaces, "surprisingRate");
  const highestUncomfortablyAccurate = pickHighest(surfaces, "uncomfortablyAccurateRate");
  const highestWowScore = pickHighest(surfaces, "averageWowScore");

  const scores = new Map<ProductSurfaceId, number>();
  for (const row of surfaces) {
    let score = 0;
    if (row.surface === highestRevisit) score += 2;
    if (row.surface === highestSurprising) score += 2;
    if (row.surface === highestUncomfortablyAccurate) score += 2;
    if (row.surface === highestWowScore) score += 2;
    if (row.openRate >= 30) score += 1;
    scores.set(row.surface, score);
  }

  const primarySurfaceCandidate =
    [...scores.entries()].sort((a, b) => b[1] - a[1])[0]?.[1] > 0
      ? ([...scores.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null)
      : null;

  const blindOpen = surfaces.find((s) => s.surface === "blind_spot")?.openRate ?? 0;
  const predictionOpen = surfaces.find((s) => s.surface === "prediction_review")?.openRate ?? 0;
  const emergingOpen = surfaces.find((s) => s.surface === "emerging_pattern")?.openRate ?? 0;

  const insightLines = [
    `Theory change open rate: ${theoryChangeOpenRate}% (${discoverOpens} discover opens / ${sessionCount} sessions).`,
    `Blind spot open rate: ${blindOpen}% · prediction review: ${predictionOpen}% · emerging pattern: ${emergingOpen}%.`,
    highestRevisit
      ? `Highest revisit rate: ${SURFACE_LABELS[highestRevisit]} (${surfaces.find((s) => s.surface === highestRevisit)?.revisitRate ?? 0}%).`
      : "No revisit signal yet.",
    highestSurprising
      ? `Highest surprising rate: ${SURFACE_LABELS[highestSurprising]} (${surfaces.find((s) => s.surface === highestSurprising)?.surprisingRate ?? 0}%).`
      : "No surprising feedback yet.",
    highestUncomfortablyAccurate
      ? `Highest uncomfortably accurate rate: ${SURFACE_LABELS[highestUncomfortablyAccurate]} (${surfaces.find((s) => s.surface === highestUncomfortablyAccurate)?.uncomfortablyAccurateRate ?? 0}%).`
      : "No uncomfortably accurate reactions yet.",
    highestWowScore
      ? `Highest average wow score: ${SURFACE_LABELS[highestWowScore]} (${surfaces.find((s) => s.surface === highestWowScore)?.averageWowScore ?? 0}).`
      : "No wow score data yet.",
    primarySurfaceCandidate
      ? `Primary surface candidate (measurement only): ${SURFACE_LABELS[primarySurfaceCandidate]}.`
      : "Insufficient data to rank a primary surface.",
  ];

  return {
    generatedAt: new Date().toISOString(),
    sessionCount,
    theoryChangeOpenRate,
    surfaces,
    highestRevisit,
    highestSurprising,
    highestUncomfortablyAccurate,
    highestWowScore,
    primarySurfaceCandidate,
    insightLines,
  };
}

export function countDiscoverOpens(): number {
  return countEvents("discover_opened");
}
