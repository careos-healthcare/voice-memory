import {
  buildFunnelConversions,
  buildFunnelStageRows,
  computeFunnelMetrics,
  listFunnelEvents,
  readFunnelState,
} from "@/lib/retention/first-week-funnel";
import type { FirstWeekFunnelDebugReport } from "@/types/first-week-funnel";

/** Internal review — recognition funnel, not recording-only. */
export function buildFirstWeekFunnelDebugReport(): FirstWeekFunnelDebugReport {
  const state = readFunnelState();
  const stages = buildFunnelStageRows(state);
  const metrics = computeFunnelMetrics(state);
  const recentEvents = listFunnelEvents(48);

  return {
    generatedAt: new Date().toISOString(),
    hasData: stages.some((row) => row.reached),
    stages,
    conversions: buildFunnelConversions(state),
    metrics,
    recentEvents,
  };
}
