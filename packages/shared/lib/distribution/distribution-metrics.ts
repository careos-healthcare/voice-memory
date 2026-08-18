import { DISTRIBUTION_EVENTS } from "@/lib/distribution/distribution-events";
import { readDistributionTestimonials } from "@/lib/distribution/testimonial-store";
import { readDistributionMoments } from "@/lib/distribution/transformation-moments";
import { readLocalEvents } from "@/lib/local-analytics";
import type {
  DistributionMetricRates,
  DistributionMomentAttribution,
  TransformationMomentType,
} from "@/types/distribution";

const MOMENT_LABELS: Record<TransformationMomentType, string> = {
  first_belief: "First belief",
  belief_change: "Belief change",
  belief_challenged: "Belief challenged",
  archive_changed_while_away: "Archive changed while away",
  first_contradiction: "First contradiction",
  first_strong_attachment: "Strong attachment",
  first_return_after_archive_change: "Return after archive change",
};

function rate(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.min(100, Math.round((numerator / denominator) * 100));
}

function countEvents(name: string, momentType?: TransformationMomentType): number {
  return readLocalEvents().filter((e) => {
    if (e.name !== name) return false;
    if (!momentType) return true;
    return e.meta?.momentType === momentType || e.meta?.trigger === momentType;
  }).length;
}

export function computeDistributionScore(rates: {
  shareRate: number | null;
  referralRate: number | null;
  testimonialRate: number | null;
  creatorStoryRate: number | null;
}): number {
  const share = rates.shareRate ?? 0;
  const referral = rates.referralRate ?? 0;
  const testimonial = rates.testimonialRate ?? 0;
  const creator = rates.creatorStoryRate ?? 0;
  return Math.min(
    100,
    Math.round(share * 0.3 + referral * 0.25 + testimonial * 0.25 + creator * 0.2),
  );
}

export function buildDistributionMetricRates(): DistributionMetricRates {
  const moments = readDistributionMoments().length;
  const denominator = Math.max(1, moments);

  const shareActions =
    countEvents(DISTRIBUTION_EVENTS.shareCardCopied) +
    countEvents(DISTRIBUTION_EVENTS.shareCardExported) +
    countEvents(DISTRIBUTION_EVENTS.shareArchiveClicked);
  const referralActions = countEvents(DISTRIBUTION_EVENTS.shareArchiveClicked);
  const testimonialActions = readDistributionTestimonials().length;
  const creatorActions = countEvents(DISTRIBUTION_EVENTS.creatorStoryCopied);

  const shareRate = rate(shareActions, denominator);
  const referralRate = rate(referralActions, denominator);
  const testimonialRate = rate(testimonialActions, denominator);
  const creatorStoryRate = rate(creatorActions, denominator);

  return {
    shareRate,
    referralRate,
    testimonialRate,
    creatorStoryRate,
    distributionScore: computeDistributionScore({
      shareRate,
      referralRate,
      testimonialRate,
      creatorStoryRate,
    }),
  };
}

export function buildDistributionMomentAttribution(): DistributionMomentAttribution[] {
  const types = Object.keys(MOMENT_LABELS) as TransformationMomentType[];
  return types.map((momentType) => ({
    momentType,
    label: MOMENT_LABELS[momentType],
    shareCount:
      countEvents(DISTRIBUTION_EVENTS.shareCardCopied, momentType) +
      countEvents(DISTRIBUTION_EVENTS.shareCardExported, momentType),
    referralCount: countEvents(DISTRIBUTION_EVENTS.shareArchiveClicked, momentType),
    testimonialCount: readDistributionTestimonials().filter(
      (t) => t.momentType === momentType,
    ).length,
  }));
}
