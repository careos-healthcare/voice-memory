/** Internal Surface Consolidation v3 — archive registry types. */

export type InternalArchiveStatus = "ACTIVE" | "ARCHIVED" | "DELETE_CANDIDATE";

export type InternalCommandPillar =
  | "activation"
  | "return"
  | "conversion"
  | "distribution"
  | "mobile";

export type LaunchReadinessVerdict = "NOT_READY" | "ALMOST_READY" | "READY";

export type InternalArchiveRecord = {
  id: string;
  route: string;
  label: string;
  status: InternalArchiveStatus;
  discoverable: boolean;
  pillar?: InternalCommandPillar;
  mergedInto?: string;
  panelComponent?: string;
  hasEvents: boolean;
  hasUsageSignals: boolean;
  drivesDecisions: boolean;
  decisionQuestion?: string;
  decisionAction?: string;
  staleSinceDays?: number;
  staleReason?: string;
};

export type FounderFocusScoreReport = {
  score: number;
  target: number;
  activeDashboards: number;
  archivedDashboards: number;
  deleteCandidates: number;
  discoverableRoutes: number;
  northStarCoverage: number;
  summary: string;
};

export type LaunchReadinessReport = {
  generatedAt: string;
  verdict: LaunchReadinessVerdict;
  mobileReadiness: { label: string; ready: boolean; detail: string };
  storeReadiness: { label: string; ready: boolean; detail: string };
  distributionReadiness: { label: string; ready: boolean; detail: string };
  revenueReadiness: { label: string; ready: boolean; detail: string };
  activationReadiness: { label: string; ready: boolean; detail: string };
};
