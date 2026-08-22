import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import { readNotificationLifecycleRecords } from "@/lib/theories/theory-notification-lifecycle";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import type {
  BreakthroughInsightProfile,
  BreakthroughTrackingReport,
  BreakthroughType,
  InsightDimensionBreakdown,
} from "@/types/breakthrough-tracking";

const BEHAVIOR_CHANGE_TYPES: BreakthroughType[] = [
  "behavior_changed",
  "acted_differently",
  "noticed_pattern",
  "blind_spot_resolved",
];

const DIMENSION_LABELS: Record<keyof BreakthroughInsightProfile, string> = {
  hasContradiction: "Contradiction",
  hasPredictionFailure: "Prediction failure",
  hasCostEvidence: "Cost evidence",
  hasCrossLifeArea: "Cross-life-area",
  hasLongTimeSpan: "Long time span",
};

function pct(numerator: number, denominator: number): number | null {
  if (denominator === 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function countInsightExposures(): number {
  const blind = readAllBlindSpotFeedback().length;
  const theory = readAllTheoryFeedback().length;
  return blind + theory;
}

function isYesBreakthrough(answer: string): boolean {
  return answer === "yes";
}

function isBehaviorChange(type: BreakthroughType): boolean {
  return BEHAVIOR_CHANGE_TYPES.includes(type);
}

function buildDimensionRows(
  events: ReturnType<typeof readAllBreakthroughEvents>,
): InsightDimensionBreakdown[] {
  const dimensions = Object.keys(DIMENSION_LABELS) as Array<keyof BreakthroughInsightProfile>;

  return dimensions.map((dimension) => {
    const withProfile = events.filter((e) => e.attribution.insightProfile);
    const tagged = withProfile.filter((e) => e.attribution.insightProfile?.[dimension]);
    const yes = tagged.filter((e) => isYesBreakthrough(e.answer));
    const behaviorYes = tagged.filter(
      (e) => isYesBreakthrough(e.answer) && isBehaviorChange(e.type),
    );

    return {
      dimension,
      label: DIMENSION_LABELS[dimension],
      insightCount: tagged.length,
      breakthroughYes: yes.length,
      behaviorChangeYes: behaviorYes.length,
      breakthroughRate: pct(yes.length, tagged.length),
      behaviorChangeRate: pct(behaviorYes.length, tagged.length),
    };
  });
}

function buildByTheoryType(
  events: ReturnType<typeof readAllBreakthroughEvents>,
): BreakthroughTrackingReport["byTheoryType"] {
  const groups = new Map<string, number>();

  for (const event of events.filter((e) => isYesBreakthrough(e.answer))) {
    const type =
      event.attribution.relatedNotificationType ??
      (event.relatedTheoryId ? "theory_linked" : "unattributed");
    groups.set(type, (groups.get(type) ?? 0) + 1);
  }

  const insightCount = countInsightExposures() || 1;
  return [...groups.entries()]
    .map(([theoryType, breakthroughs]) => ({
      theoryType,
      breakthroughs,
      perHundred: Math.round((breakthroughs / insightCount) * 10000) / 100,
    }))
    .sort((a, b) => b.breakthroughs - a.breakthroughs);
}

export function buildBreakthroughTrackingReport(): BreakthroughTrackingReport {
  const events = readAllBreakthroughEvents();
  const responses = events.length;
  const yesEvents = events.filter((e) => isYesBreakthrough(e.answer));
  const insightExposureCount = countInsightExposures();
  const openedNotificationCount = readNotificationLifecycleRecords().filter(
    (r) => r.openedAt,
  ).length;

  const withNotification = yesEvents.filter(
    (e) => e.attribution.relatedNotificationId,
  ).length;

  const dimensions = buildDimensionRows(events);
  const sortedByBehavior = [...dimensions].sort(
    (a, b) => (b.behaviorChangeRate ?? -1) - (a.behaviorChangeRate ?? -1),
  );
  const top = sortedByBehavior[0];

  const lines: string[] = [
    `${yesEvents.length} yes breakthroughs from ${responses} prompt responses.`,
    insightExposureCount > 0
      ? `${pct(yesEvents.length, insightExposureCount) ?? 0}% of recorded insight feedback (yes / exposures).`
      : "No insight feedback recorded yet.",
    openedNotificationCount > 0
      ? `${withNotification} yes breakthroughs linked to an opened notification (${openedNotificationCount} opens).`
      : "No opened theory notifications yet.",
    top && top.insightCount > 0
      ? `Strongest behavior-change signal: ${top.label} (${top.behaviorChangeRate ?? "—"}% yes with dimension).`
      : "Insight dimension comparison needs more breakthrough responses.",
  ];

  return {
    generatedAt: new Date().toISOString(),
    totalBreakthroughs: yesEvents.length,
    totalPromptResponses: responses,
    breakthroughRate: pct(yesEvents.length, responses),
    breakthroughsPer100Insights:
      insightExposureCount > 0
        ? Math.round((yesEvents.length / insightExposureCount) * 10000) / 100
        : null,
    breakthroughsPerNotification:
      openedNotificationCount > 0
        ? Math.round((withNotification / openedNotificationCount) * 1000) / 10
        : null,
    insightExposureCount,
    openedNotificationCount,
    byTheoryType: buildByTheoryType(events),
    winningInsightTitle: "What kinds of insights lead to behavior change?",
    insightDimensions: dimensions,
    behaviorChangeTypes: BEHAVIOR_CHANGE_TYPES,
    lines,
  };
}
