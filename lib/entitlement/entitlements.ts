import { entitlementsForTier, TIER_BY_ID } from "@/lib/entitlement/tiers";
import {
  PRO_GATE_DEEPER_RESURFACING,
  PRO_GATE_EXPORT,
  PRO_GATE_UNLIMITED_ARCHIVE,
} from "@/lib/product/pro-framing";
import { isProPreviewAllowed } from "@/lib/billing/billing-state";
import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import type {
  EntitlementId,
  EntitlementRecord,
  TierId,
  TierSnapshot,
} from "@/types/entitlement";

const PLAN_KEY = "voicememory_plan";
const BILLING_ENTITLEMENT_KEY = "voicememory_billing_entitlements";
const SERVER_ENTITLEMENT_CACHE_KEY = "voicememory_server_entitlement_snapshot";

interface ServerEntitlementSnapshot {
  tier: TierId;
  entitlements: EntitlementId[];
  source: "paid" | "free_tier";
  billingConnected: boolean;
  previewMode: boolean;
  founderPreview: boolean;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Raw plan flag in localStorage (may be preview-only). */
export function getCurrentTierId(): TierId {
  if (!isBrowser()) return "free";
  return localStorage.getItem(PLAN_KEY) === "pro" ? "pro" : "free";
}

function readServerEntitlementSnapshot(): ServerEntitlementSnapshot | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(SERVER_ENTITLEMENT_CACHE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as ServerEntitlementSnapshot;
  } catch {
    return null;
  }
}

/** Pull tier + entitlements from server when billing is live (fail closed until synced). */
export async function refreshServerEntitlements(): Promise<ServerEntitlementSnapshot | null> {
  if (!isBrowser() || !isLiveBillingAvailable()) return null;
  try {
    const res = await fetch("/api/billing/entitlements", {
      credentials: "include",
    });
    if (!res.ok) return null;
    const data = (await res.json()) as ServerEntitlementSnapshot;
    sessionStorage.setItem(SERVER_ENTITLEMENT_CACHE_KEY, JSON.stringify(data));
    if (data.tier === "pro" && data.source === "paid") {
      setBillingGrantedEntitlements(entitlementsForTier("pro"));
    } else if (data.tier === "free") {
      clearBillingGrantedEntitlements();
      localStorage.setItem(PLAN_KEY, "free");
    }
    return data;
  } catch {
    return null;
  }
}

/** Effective tier — server-backed when billing live; preview never masquerades as paid. */
export function getEffectiveTierId(): TierId {
  if (isLiveBillingAvailable()) {
    const server = readServerEntitlementSnapshot();
    if (server) return server.tier;
    return "free";
  }
  const raw = getCurrentTierId();
  if (raw === "pro" && !isProPreviewAllowed()) {
    return "free";
  }
  return raw;
}

function readBillingGrantedEntitlements(): EntitlementId[] {
  if (!isBrowser() || !isLiveBillingAvailable()) return [];
  try {
    const raw = localStorage.getItem(BILLING_ENTITLEMENT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (id): id is EntitlementId =>
        typeof id === "string" &&
        entitlementsForTier("pro").includes(id as EntitlementId),
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
  const wasPro = localStorage.getItem(PLAN_KEY) === "pro";
  localStorage.setItem(PLAN_KEY, tier);
  if (tier === "pro" && !wasPro) {
    void import("@/lib/behavior/observation").then((mod) => {
      mod.trackProPreviewEnabled("preview_tier");
    });
  }
}

export function getTierSnapshot(): TierSnapshot {
  const billingConnected = isLiveBillingAvailable();
  const server = readServerEntitlementSnapshot();
  const previewMode =
    isBrowser() &&
    !billingConnected &&
    getCurrentTierId() === "pro" &&
    isProPreviewAllowed();

  if (billingConnected && server) {
    return {
      tier: server.tier,
      entitlements: server.entitlements,
      billingConnected: true,
      previewMode: false,
    };
  }

  const tier = getEffectiveTierId();
  const granted = new Set<EntitlementId>(entitlementsForTier(tier));
  for (const id of readBillingGrantedEntitlements()) {
    granted.add(id);
  }
  return {
    tier,
    entitlements: [...granted],
    billingConnected,
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
    source:
      snapshot.previewMode && snapshot.tier === "pro" ? "preview" : "tier",
  }));
}

export function requiresEntitlement(id: EntitlementId): boolean {
  return !hasEntitlement(id);
}

const GATE_COPY: Partial<
  Record<EntitlementId, { title: string; detail: string; feature: string }>
> = {
  unlimited_archive: PRO_GATE_UNLIMITED_ARCHIVE,
  open_loops: {
    title: "Open loops are part of Pro",
    detail:
      "Keep unfinished threads in your own words — no tasks, reminders, or advice.",
    feature: "open_loops",
  },
  export_reports: PRO_GATE_EXPORT,
  encrypted_backup: {
    title: "Encrypted backup is part of Pro",
    detail: "Sign in to sync an encrypted copy of your archive across devices.",
    feature: "encrypted_backup",
  },
  deeper_resurfacing: PRO_GATE_DEEPER_RESURFACING,
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
  return getEffectiveTierId() === "pro";
}
