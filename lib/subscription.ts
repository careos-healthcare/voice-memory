import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  FREE_ARCHIVE_LIMIT,
  getCurrentTierId,
  hasEntitlement,
  isProTier,
  setPreviewTier,
} from "@/lib/entitlement/entitlements";
import type { EntitlementId } from "@/types/entitlement";
import { FREE_TIER, PRO_TIER } from "@/lib/entitlement/tiers";
import { getPaymentStackAudit, isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";

export type PlanId = "free" | "pro";

export type UpgradeClickSource =
  | "pricing"
  | "memory"
  | "weekly"
  | "search"
  | "export"
  | "journal"
  | "insights"
  | "homepage"
  | "pilot"
  | "open_loops";

export interface UpgradeClickEvent {
  source: UpgradeClickSource;
  clickedAt: string;
  feature?: string;
}

export const FREE_ENTRY_LIMIT = FREE_ARCHIVE_LIMIT;
export const PRO_PRICE_LABEL = PRO_TIER.priceLabel;

const UPGRADE_CLICKS_KEY = "voicememory_upgrade_clicks";

export interface ProMemoryFeature {
  id: string;
  title: string;
  description: string;
  comingSoon?: boolean;
}

export const PRO_MEMORY_FEATURES: ProMemoryFeature[] = [
  {
    id: "unlimited_archive",
    title: "Unlimited archive",
    description: "Every reflection stays active in memory — not just your last seven.",
  },
  {
    id: "encrypted_backup",
    title: "Encrypted backup",
    description: "Encrypted sync when you sign in — your archive, not our product feed.",
    comingSoon: !isLiveBillingAvailable(),
  },
  {
    id: "open_loops",
    title: "Open loops",
    description: "Keep unfinished threads with your own next step — no nudges from us.",
  },
  {
    id: "export_reports",
    title: "Export",
    description: "Full-archive JSON, weekly text exports, and printable reflection reports.",
  },
  {
    id: "deeper_resurfacing",
    title: "Deeper resurfacing",
    description: "Continuity and callbacks drawn from your full history, in your words.",
  },
];

export const FREE_PLAN_FEATURES = FREE_TIER.featureBullets;
export const PRO_PLAN_FEATURES = PRO_TIER.featureBullets;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getPlanId(): PlanId {
  return getCurrentTierId();
}

export function isProUser(): boolean {
  return isProTier();
}

/** Local Pro preview until live billing is connected. */
export function setPlanId(plan: PlanId): void {
  setPreviewTier(plan);
}

export function trackUpgradeClick(
  source: UpgradeClickSource,
  feature?: string,
): void {
  if (!isBrowser()) return;

  const event: UpgradeClickEvent = {
    source,
    clickedAt: new Date().toISOString(),
    feature,
  };

  try {
    const raw = localStorage.getItem(UPGRADE_CLICKS_KEY);
    const existing = raw ? (JSON.parse(raw) as UpgradeClickEvent[]) : [];
    existing.push(event);
    localStorage.setItem(
      UPGRADE_CLICKS_KEY,
      JSON.stringify(existing.slice(-100)),
    );
    trackLaunchEvent(LAUNCH_EVENTS.upgradeClicked, { source, feature: feature ?? "" });
  } catch {
    localStorage.setItem(UPGRADE_CLICKS_KEY, JSON.stringify([event]));
    trackLaunchEvent(LAUNCH_EVENTS.upgradeClicked, { source, feature: feature ?? "" });
  }
}

export function getUpgradeClickEvents(): UpgradeClickEvent[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(UPGRADE_CLICKS_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as UpgradeClickEvent[];
  } catch {
    return [];
  }
}

export function requiresProForExportReports(): boolean {
  return hasEntitlement("export_reports") === false;
}

export function requiresProForOpenLoops(): boolean {
  return hasEntitlement("open_loops") === false;
}

export function requiresProForEncryptedBackup(): boolean {
  return hasEntitlement("encrypted_backup") === false;
}

export function clearProPreview(): void {
  setPreviewTier("free");
}

export { getPaymentStackAudit, hasEntitlement };
export type { EntitlementId };
