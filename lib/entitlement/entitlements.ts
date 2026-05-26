import { entitlementsForTier, FREE_ARCHIVE_LIMIT, TIER_BY_ID } from "@/lib/entitlement/tiers";
import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import type { EntitlementId, EntitlementRecord, TierId, TierSnapshot } from "@/types/entitlement";

const PLAN_KEY = "voicememory_plan";
const BILLING_ENTITLEMENT_KEY = "voicememory_billing_entitlements";

export { FREE_ARCHIVE_LIMIT };

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Active tier from local plan flag (Pro preview or future billing sync). */
export function getCurrentTierId(): TierId {
  if (!isBrowser()) return "free";
  return localStorage.getItem(PLAN_KEY) === "pro" ? "pro" : "free";
}

function readBillingGrantedEntitlements(): EntitlementId[] {
  if (!isBrowser() || !isLiveBillingAvailable()) return [];
  try {
    const raw = localStorage.getItem(BILLING_ENTITLEMENT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((id): id is EntitlementId =>
      typeof id === "string" && entitlementsForTier("pro").includes(id as EntitlementId),
    );
  } catch {
    return [];
  }
}

/** Persist entitlements granted by a billing provider (Stripe webhook / client sync). */
export function setBillingGrantedEntitlements(ids: EntitlementId[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(BILLING_ENTITLEMENT_KEY, JSON.stringify(ids));
  if (ids.length > 0) {
    localStorage.setItem(PLAN_KEY, "pro");
  }
}

export function clearBillingGrantedEntitlements(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(BILLING_ENTITLEMENT_KEY);
}

export function setPreviewTier(tier: TierId): void {
  if (!isBrowser()) return;
  localStorage.setItem(PLAN_KEY, tier);
}

export function getTierSnapshot(): TierSnapshot {
  const tier = getCurrentTierId();
  const previewMode = isBrowser() && !isLiveBillingAvailable() && tier === "pro";
  const granted = new Set<EntitlementId>(entitlementsForTier(tier));
  for (const id of readBillingGrantedEntitlements()) {
    granted.add(id);
  }
  return {
    tier,
    entitlements: [...granted],
    billingConnected: isLiveBillingAvailable(),
    previewMode,
  };
}

export function hasEntitlement(id: EntitlementId): boolean {
  return getTierSnapshot().entitlements.includes(id);
}

export function listEntitlementRecords(): EntitlementRecord[] {
  const snapshot = getTierSnapshot();
  const all: EntitlementId[] = [
    "local_recording",
    "limited_archive",
    "basic_resurfacing",
    "unlimited_archive",
    "encrypted_backup",
    "open_loops",
    "export_reports",
    "deeper_resurfacing",
  ];
  return all.map((id) => ({
    id,
    tier: snapshot.tier,
    granted: snapshot.entitlements.includes(id),
    source: snapshot.previewMode && snapshot.tier === "pro" ? "preview" : "tier",
  }));
}

export function requiresEntitlement(id: EntitlementId): boolean {
  return !hasEntitlement(id);
}

const GATE_COPY: Partial<
  Record<EntitlementId, { title: string; detail: string; feature: string }>
> = {
  unlimited_archive: {
    title: "Full archive is part of Pro",
    detail: "Your reflections stay on device. Pro unlocks your full history in memory and search.",
    feature: "unlimited_archive",
  },
  open_loops: {
    title: "Open loops are part of Pro",
    detail: "Keep unfinished threads in your own words — no tasks, reminders, or advice.",
    feature: "open_loops",
  },
  export_reports: {
    title: "Export reports are part of Pro",
    detail: "Full-archive export, weekly summaries, and printable reports.",
    feature: "export_reports",
  },
  encrypted_backup: {
    title: "Encrypted backup is part of Pro",
    detail: "Sign in to sync an encrypted copy of your archive across devices.",
    feature: "encrypted_backup",
  },
  deeper_resurfacing: {
    title: "Full-history resurfacing is part of Pro",
    detail: "Pro connects patterns across your whole archive, not just recent reflections.",
    feature: "deeper_resurfacing",
  },
};

export function entitlementGateCopy(id: EntitlementId): {
  title: string;
  detail: string;
  feature: string;
} {
  return (
    GATE_COPY[id] ?? {
      title: "This is part of Pro",
      detail: TIER_BY_ID.pro.headline,
      feature: id,
    }
  );
}

export function isProTier(): boolean {
  return getCurrentTierId() === "pro";
}
