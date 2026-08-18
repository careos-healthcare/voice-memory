import {
  FOUNDER_DASHBOARD_TAB_COPY,
} from "@/lib/internal/founder-focus-copy";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";
import type {
  FounderArchiveDashboardView,
  FounderDashboardTabId,
  NorthStarMetricId,
} from "@/types/founder-focus";

const TAB_METRICS: Record<FounderDashboardTabId, NorthStarMetricId[]> = {
  activation: ["activation", "curiosity"],
  return: ["return", "attachment"],
  conversion: ["conversion"],
};

export function buildFounderArchiveDashboard(): FounderArchiveDashboardView {
  const northStar = buildNorthStarDashboard();
  const metricById = new Map(northStar.metrics.map((m) => [m.id, m]));

  const tabs = (Object.keys(TAB_METRICS) as FounderDashboardTabId[]).map((id) => {
    const copy = FOUNDER_DASHBOARD_TAB_COPY[id];
    const metrics = TAB_METRICS[id]
      .map((mid) => metricById.get(mid))
      .filter((m): m is NonNullable<typeof m> => Boolean(m));

    return {
      id,
      label: copy.label,
      headline: copy.headline,
      bullets: metrics.map((m) => `${m.title}: ${m.value} — ${m.subtitle}`),
      metricIds: TAB_METRICS[id],
    };
  });

  return {
    generatedAt: northStar.generatedAt,
    tabs,
  };
}

export const FOUNDER_DASHBOARD_TAB_COUNT = 3;
