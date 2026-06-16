export type ValueMomentKey =
  | "first_blind_spot_seen"
  | "first_discover_seen"
  | "post_blind_spot_value"
  | "post_discover_value"
  | "archive_continuity";

export type ValueMomentPaywallSurface = "blind_spot" | "discover" | "archive_continuity";

export interface ValueMomentPaywallStorage {
  hasSeenFirstBlindSpot: boolean;
  hasSeenFirstDiscover: boolean;
  postBlindSpotPaywallSeen: boolean;
  postDiscoverPaywallSeen: boolean;
  blindSpotsVisitCount: number;
  discoverVisitCount: number;
}

export interface ValueMomentState {
  reflectionCount: number;
  hasSeenFirstBlindSpot: boolean;
  hasSeenFirstDiscover: boolean;
  hasReachedFiveReflections: boolean;
  shouldShowPostBlindSpotPaywall: boolean;
  shouldShowPostDiscoverPaywall: boolean;
  shouldGateArchiveContinuity: boolean;
  freeValueUsed: boolean;
  reason: string;
}

export interface ValueMomentPaywallSurfaceBreakdown {
  blind_spot: number;
  discover: number;
  archive_continuity: number;
}

export interface ValueMomentPaywallMetricsReport {
  generatedAt: string;
  shownCount: number;
  ctaClickedCount: number;
  dismissedCount: number;
  ctaClickRate: number | null;
  dismissRate: number | null;
  surfaceBreakdown: ValueMomentPaywallSurfaceBreakdown;
  shownAfterBlindSpotCount: number;
  shownAfterDiscoverCount: number;
  conversionProxyPercent: number | null;
  lines: string[];
}
