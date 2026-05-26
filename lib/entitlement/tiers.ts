import type { EntitlementId, TierId } from "@/types/entitlement";

export const FREE_ARCHIVE_LIMIT = 7;

export interface TierDefinition {
  id: TierId;
  label: string;
  priceLabel: string;
  headline: string;
  entitlements: EntitlementId[];
  featureBullets: string[];
}

/** Free — local recording, limited archive, basic resurfacing. */
export const FREE_TIER: TierDefinition = {
  id: "free",
  label: "Free",
  priceLabel: "£0",
  headline: "Local-first reflections on your device",
  entitlements: ["local_recording", "limited_archive", "basic_resurfacing"],
  featureBullets: [
    "Voice recording and transcript on this device",
    `Last ${FREE_ARCHIVE_LIMIT} reflections in your active archive`,
    "Quiet resurfacing from recent reflections",
    "Local storage — private by default",
  ],
};

/** Pro — unlimited archive, backup, open loops, export, deeper resurfacing. */
export const PRO_TIER: TierDefinition = {
  id: "pro",
  label: "Pro",
  priceLabel: "£8.99/month",
  headline: "Your full private archive",
  entitlements: [
    "local_recording",
    "unlimited_archive",
    "basic_resurfacing",
    "deeper_resurfacing",
    "encrypted_backup",
    "open_loops",
    "export_reports",
  ],
  featureBullets: [
    "Unlimited reflection archive on device",
    "Encrypted backup when you sign in (sync)",
    "Open loops — your words, your next step",
    "Export JSON, weekly summaries, and print reports",
    "Deeper resurfacing across your full history",
  ],
};

export const TIER_BY_ID: Record<TierId, TierDefinition> = {
  free: FREE_TIER,
  pro: PRO_TIER,
};

export function entitlementsForTier(tier: TierId): EntitlementId[] {
  return [...TIER_BY_ID[tier].entitlements];
}
