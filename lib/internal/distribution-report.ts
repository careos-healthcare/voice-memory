import {
  buildDistributionMetricRates,
  buildDistributionMomentAttribution,
} from "@/lib/distribution/distribution-metrics";
import { readDistributionTestimonials } from "@/lib/distribution/testimonial-store";
import type { DistributionReport } from "@/types/distribution";

function topLabels(
  rows: ReturnType<typeof buildDistributionMomentAttribution>,
  pick: (row: (typeof rows)[number]) => number,
  limit = 5,
): string[] {
  return [...rows]
    .sort((a, b) => pick(b) - pick(a))
    .filter((row) => pick(row) > 0)
    .slice(0, limit)
    .map((row) => row.label);
}

/** Why people share — moment attribution for internal review. */
export function buildDistributionReport(): DistributionReport {
  const momentAttribution = buildDistributionMomentAttribution();
  const rates = buildDistributionMetricRates();
  const testimonials = readDistributionTestimonials();

  return {
    generatedAt: new Date().toISOString(),
    momentAttribution,
    rates,
    topSharingMoments: topLabels(momentAttribution, (r) => r.shareCount),
    topReferralMoments: topLabels(momentAttribution, (r) => r.referralCount),
    topTestimonialMoments: topLabels(momentAttribution, (r) => r.testimonialCount),
    testimonialSamples: testimonials
      .slice(-6)
      .map((t) => t.text)
      .filter(Boolean),
  };
}
