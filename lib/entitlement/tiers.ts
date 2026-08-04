import { PRO_FEATURE_BULLETS, PRO_HEADLINE } from "@/lib/product/pro-framing";
import type { EntitlementId, TierId } from "@/types/entitlement";

export interface TierDefinition {
  id: TierId;
  label: string;
  priceLabel: string;
  headline: string;
  entitlements: EntitlementId[];
  featureBullets: string[];
}

/** Free — user-owned content plus the first evidence-backed value. */
export const FREE_TIER: TierDefinition = {
  id: "free",
  label: "Free",
  priceLabel: "Free",
  headline: "Local-first reflections on your device",
  entitlements: ["local_recording", "unlimited_archive", "basic_resurfacing"],
  featureBullets: [
    "Voice recording and transcript on this device",
    "Every original reflection remains accessible",
    "First evidence-backed observation and comparison",
    "Local storage — private by default",
  ],
};

/** Pro — deeper resurfacing and long-term continuity; export is secondary. */
export const PRO_TIER: TierDefinition = {
  id: "pro",
  label: "Pro",
  priceLabel: "Store price",
  headline: PRO_HEADLINE,
  entitlements: [
    "local_recording",
    "unlimited_archive",
    "basic_resurfacing",
    "deeper_resurfacing",
    "encrypted_backup",
    "open_loops",
    "export_reports",
  ],
  featureBullets: [...PRO_FEATURE_BULLETS],
};

export const TIER_BY_ID: Record<TierId, TierDefinition> = {
  free: FREE_TIER,
  pro: PRO_TIER,
};

export function entitlementsForTier(tier: TierId): EntitlementId[] {
  return [...TIER_BY_ID[tier].entitlements];
}
