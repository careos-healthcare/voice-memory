/** Founder Complexity Reduction v2 — internal north star only. */

export type NorthStarMetricId =
  | "activation"
  | "return"
  | "curiosity"
  | "attachment"
  | "conversion";

export type FounderDashboardTabId = "activation" | "return" | "conversion";

export type FounderPriorityTier = "CORE" | "SUPPORTING" | "ARCHIVED";

export type FounderDecisionScore = "YES" | "NO";

export type NorthStarMetricView = {
  id: NorthStarMetricId;
  title: string;
  subtitle: string;
  value: string;
  detail: string;
};

export type NorthStarDashboardView = {
  generatedAt: string;
  metrics: NorthStarMetricView[];
};

export type FounderDashboardTabView = {
  id: FounderDashboardTabId;
  label: string;
  headline: string;
  bullets: string[];
  metricIds: NorthStarMetricId[];
};

export type FounderArchiveDashboardView = {
  generatedAt: string;
  tabs: FounderDashboardTabView[];
};
