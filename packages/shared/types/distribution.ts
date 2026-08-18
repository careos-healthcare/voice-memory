/** Distribution Engine v1 — acquisition moments, share, testimonials, metrics. */

export type TransformationMomentType =
  | "first_belief"
  | "belief_change"
  | "belief_challenged"
  | "archive_changed_while_away"
  | "first_contradiction"
  | "first_strong_attachment"
  | "first_return_after_archive_change";

export type DistributionWorthyMoment = {
  id: string;
  type: TransformationMomentType;
  detectedAt: string;
  theoryId?: string;
  /** Safe public headline — no reflection text. */
  headline: string;
  distributionWorthy: boolean;
  meta?: Record<string, string>;
};

export type ArchiveShareCardVariant =
  | "belief_changed_mind"
  | "pattern_tracked_days"
  | "no_longer_believes"
  | "survived_challenges";

export type ArchiveShareCardModel = {
  id: string;
  variant: ArchiveShareCardVariant;
  line: string;
  subline?: string;
  momentType?: TransformationMomentType;
};

export type DistributionTestimonial = {
  id: string;
  momentType: TransformationMomentType;
  text: string;
  rating: 1 | 2 | 3 | 4 | 5;
  capturedAt: string;
};

export type CreatorStoryFormat = "tiktok" | "instagram" | "shorts";

export type CreatorStory = {
  hook: string;
  archiveMoment: string;
  result: string;
  full: string;
};

export type CreatorKitSection = {
  title: string;
  items: string[];
};

export type CreatorKit = {
  generatedAt: string;
  hooks: string[];
  storyTemplates: string[];
  screenshotExamples: string[];
  archiveMoments: string[];
};

export type DistributionMetricRates = {
  shareRate: number | null;
  referralRate: number | null;
  testimonialRate: number | null;
  creatorStoryRate: number | null;
  distributionScore: number;
};

export type DistributionMomentAttribution = {
  momentType: TransformationMomentType;
  label: string;
  shareCount: number;
  referralCount: number;
  testimonialCount: number;
};

export type DistributionReport = {
  generatedAt: string;
  momentAttribution: DistributionMomentAttribution[];
  rates: DistributionMetricRates;
  topSharingMoments: string[];
  topReferralMoments: string[];
  topTestimonialMoments: string[];
  testimonialSamples: string[];
};
