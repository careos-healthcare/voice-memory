import "server-only";

import { entitlementsForTier } from "@/lib/entitlement/tiers";
import type { EntitlementId } from "@/types/entitlement";

const REVENUECAT_SECRET_API_KEY = process.env.REVENUECAT_SECRET_API_KEY?.trim();
const REVENUECAT_PRO_ENTITLEMENT_ID =
  process.env.REVENUECAT_PRO_ENTITLEMENT_ID?.trim() || "pro";

interface RevenueCatEntitlementPayload {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  product_identifier?: string;
}

interface RevenueCatSubscriberResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlementPayload>;
  };
}

function isEntitlementActive(payload: RevenueCatEntitlementPayload | undefined): boolean {
  if (!payload) return false;
  const expiresRaw = payload.grace_period_expires_date ?? payload.expires_date;
  if (expiresRaw == null || expiresRaw === "") return true;
  const expiresMs = new Date(expiresRaw).getTime();
  return Number.isFinite(expiresMs) && expiresMs > Date.now();
}

export function isRevenueCatRestConfigured(): boolean {
  return REVENUECAT_SECRET_API_KEY != null && REVENUECAT_SECRET_API_KEY.length > 0;
}

/** Fallback entitlement lookup for signed-in web sessions (mobile store purchases). */
export async function resolveRevenueCatSubscriberEntitlements(
  appUserId: string,
): Promise<{ tier: "free" | "pro"; entitlements: EntitlementId[] } | null> {
  if (!isRevenueCatRestConfigured()) return null;

  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        Authorization: `Bearer ${REVENUECAT_SECRET_API_KEY}`,
        Accept: "application/json",
      },
      cache: "no-store",
    },
  );

  if (response.status === 404) {
    return { tier: "free", entitlements: entitlementsForTier("free") };
  }
  if (!response.ok) return null;

  const body = (await response.json()) as RevenueCatSubscriberResponse;
  const entitlements = body.subscriber?.entitlements ?? {};
  const proPayload = entitlements[REVENUECAT_PRO_ENTITLEMENT_ID];
  if (isEntitlementActive(proPayload)) {
    return {
      tier: "pro",
      entitlements: entitlementsForTier("pro"),
    };
  }

  return { tier: "free", entitlements: entitlementsForTier("free") };
}
