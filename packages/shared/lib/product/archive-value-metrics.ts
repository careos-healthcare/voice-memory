import { stageForReflectionCount } from "@/lib/product/archive-value-progress";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { hasLocalEvent, readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  ArchiveValueMetricsReport,
  ArchiveValueStage,
} from "@/types/archive-value";

export const ARCHIVE_VALUE_EVENTS = {
  bannerShown: "archive_value_banner_shown",
  bannerCtaClicked: "archive_value_cta_clicked",
  ladderSeen: "reflection_ladder_seen",
  stageOneDataPoint: "archive_stage_reached_one_data_point",
  stagePossibleRepeat: "archive_stage_reached_possible_repeat",
  stagePatternForming: "archive_stage_reached_pattern_forming",
  stageTheoryUnderReview: "archive_stage_reached_theory_under_review",
  stagePatternReviewUnlocked: "archive_stage_reached_pattern_review_unlocked",
} as const;

const STAGE_EVENT_BY_STAGE: Record<ArchiveValueStage, string> = {
  one_data_point: ARCHIVE_VALUE_EVENTS.stageOneDataPoint,
  possible_repeat: ARCHIVE_VALUE_EVENTS.stagePossibleRepeat,
  pattern_forming: ARCHIVE_VALUE_EVENTS.stagePatternForming,
  theory_under_review: ARCHIVE_VALUE_EVENTS.stageTheoryUnderReview,
  pattern_review_unlocked: ARCHIVE_VALUE_EVENTS.stagePatternReviewUnlocked,
};

const ALL_STAGES: ArchiveValueStage[] = [
  "one_data_point",
  "possible_repeat",
  "pattern_forming",
  "theory_under_review",
  "pattern_review_unlocked",
];

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function progressionRate(fromEvent: string, toEvent: string): number | null {
  const reachedFrom = countNamed(fromEvent);
  const reachedTo = countNamed(toEvent);
  return pct(reachedTo, reachedFrom);
}

/** Record stage milestones once per device. */
export function observeArchiveValueStageMilestones(reflectionCount?: number): void {
  const count = reflectionCount ?? countCompletedReflections();
  const stage = stageForReflectionCount(count);
  const eventName = STAGE_EVENT_BY_STAGE[stage];
  if (!hasLocalEvent(eventName)) {
    trackLocalEvent(eventName, { reflectionCount: String(count) });
  }
}

export function trackArchiveValueBannerShown(reflectionCount: number, stage: ArchiveValueStage): void {
  trackLocalEvent(ARCHIVE_VALUE_EVENTS.bannerShown, {
    reflectionCount: String(reflectionCount),
    stage,
  });
  observeArchiveValueStageMilestones(reflectionCount);
}

export function trackArchiveValueCtaClicked(reflectionCount: number, stage: ArchiveValueStage): void {
  trackLocalEvent(ARCHIVE_VALUE_EVENTS.bannerCtaClicked, {
    reflectionCount: String(reflectionCount),
    stage,
  });
}

export function trackReflectionLadderSeen(reflectionCount: number): void {
  trackLocalEvent(ARCHIVE_VALUE_EVENTS.ladderSeen, {
    reflectionCount: String(reflectionCount),
  });
}

export function buildArchiveValueMetricsReport(): ArchiveValueMetricsReport {
  const stageCounts = Object.fromEntries(
    ALL_STAGES.map((stage) => [stage, countNamed(STAGE_EVENT_BY_STAGE[stage])]),
  ) as Record<ArchiveValueStage, number>;

  const bannerShownCount = countNamed(ARCHIVE_VALUE_EVENTS.bannerShown);
  const bannerCtaClickedCount = countNamed(ARCHIVE_VALUE_EVENTS.bannerCtaClicked);
  const ladderSeenCount = countNamed(ARCHIVE_VALUE_EVENTS.ladderSeen);

  const progressionRates = {
    oneToTwo: progressionRate(
      ARCHIVE_VALUE_EVENTS.stageOneDataPoint,
      ARCHIVE_VALUE_EVENTS.stagePossibleRepeat,
    ),
    twoToThree: progressionRate(
      ARCHIVE_VALUE_EVENTS.stagePossibleRepeat,
      ARCHIVE_VALUE_EVENTS.stagePatternForming,
    ),
    threeToFour: progressionRate(
      ARCHIVE_VALUE_EVENTS.stagePatternForming,
      ARCHIVE_VALUE_EVENTS.stageTheoryUnderReview,
    ),
    fourToFive: progressionRate(
      ARCHIVE_VALUE_EVENTS.stageTheoryUnderReview,
      ARCHIVE_VALUE_EVENTS.stagePatternReviewUnlocked,
    ),
  };

  const bannerClickRate = pct(bannerCtaClickedCount, bannerShownCount);

  const lines = [
    `Banner shown: ${bannerShownCount}`,
    `Banner CTA clicked: ${bannerCtaClickedCount}`,
    `Banner click rate: ${bannerClickRate ?? "—"}%`,
    `Ladder seen: ${ladderSeenCount}`,
    `1→2: ${progressionRates.oneToTwo ?? "—"}%`,
    `2→3: ${progressionRates.twoToThree ?? "—"}%`,
    `3→4: ${progressionRates.threeToFour ?? "—"}%`,
    `4→5: ${progressionRates.fourToFive ?? "—"}%`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    stageCounts,
    bannerShownCount,
    bannerCtaClickedCount,
    ladderSeenCount,
    progressionRates,
    currentReflectionCount: countCompletedReflections(),
    lines,
  };
}

export function clearArchiveValueMetricsForEval(): void {
  if (typeof globalThis.localStorage === "undefined") return;
  const names = new Set<string>(Object.values(ARCHIVE_VALUE_EVENTS));
  const kept = readLocalEvents().filter((e) => !names.has(e.name));
  globalThis.localStorage.setItem("voicememory_local_events", JSON.stringify(kept));
}
