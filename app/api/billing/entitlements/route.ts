import { NextResponse } from "next/server";

import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import { entitlementsForTier } from "@/lib/entitlement/tiers";
import { resolveServerEntitlements } from "@/lib/server/billing-entitlements";
import {
  getAuthoritativeEntitlementState,
  type AuthoritativeEntitlementState,
} from "@/lib/server/authoritative-entitlement-store";
import { getRevenueCatUserMapping } from "@/lib/server/revenuecat-mapping";
import {
  REVENUECAT_PRO_ENTITLEMENT_IDS,
  verifyRevenueCatEntitlement,
} from "@/lib/server/revenuecat-verifier";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

function grantsPro(state: AuthoritativeEntitlementState | null): boolean {
  if (
    !state ||
    !["active", "trialing", "billing_issue"].includes(state.status)
  ) {
    return false;
  }
  return (
    state.lifetime ||
    (state.periodEnd !== null && new Date(state.periodEnd) > new Date())
  );
}

/** Server-backed entitlements for signed-in users. */
export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let billingConnected = isLiveBillingAvailable();
  const [resolved, mapping, stripeState, revenueCatState] = await Promise.all([
    resolveServerEntitlements(session.userId),
    getRevenueCatUserMapping(session.userId),
    getAuthoritativeEntitlementState(session.userId, "stripe"),
    getAuthoritativeEntitlementState(session.userId, "revenuecat"),
  ]);

  let tier = resolved.tier;
  let entitlements = resolved.entitlements;
  let source: string = resolved.source === "paid" ? "stripe" : resolved.source;
  let verification: "verified" | "unavailable" = "verified";
  let verifiedAt: string | null = new Date().toISOString();
  let expirationDate: string | null = null;
  let accessKind: "free" | "pro" | "legacyGrandfathered" =
    tier === "pro" ? "pro" : "free";
  let subscriptionState:
    | "free"
    | "active"
    | "legacyGrandfathered"
    | "billingIssue"
    | "revoked" = tier === "pro" ? "active" : "free";
  const authoritativeState = grantsPro(stripeState)
    ? stripeState
    : grantsPro(revenueCatState)
      ? revenueCatState
      : null;
  const hasAuthoritativeState =
    stripeState !== null || revenueCatState !== null;
  if (authoritativeState) {
    billingConnected = true;
    tier = "pro";
    entitlements = entitlementsForTier("pro");
    source = authoritativeState.provider;
    verifiedAt = authoritativeState.providerEventTimestamp;
    expirationDate = authoritativeState.periodEnd;
    accessKind = authoritativeState.lifetime ? "legacyGrandfathered" : "pro";
    subscriptionState = authoritativeState.lifetime
      ? "legacyGrandfathered"
      : authoritativeState.status === "billing_issue"
        ? "billingIssue"
        : "active";
  } else if (hasAuthoritativeState && resolved.tier !== "pro") {
    billingConnected = true;
    tier = "free";
    entitlements = entitlementsForTier("free");
    source = revenueCatState ? "revenuecat_inactive" : "stripe_inactive";
    const inactiveState = revenueCatState ?? stripeState;
    verifiedAt = inactiveState?.providerEventTimestamp ?? verifiedAt;
    expirationDate = inactiveState?.periodEnd ?? null;
    accessKind = "free";
    subscriptionState = "revoked";
  } else if (mapping && !hasAuthoritativeState) {
    const revenueCat = await verifyRevenueCatEntitlement(
      mapping.appUserId,
      REVENUECAT_PRO_ENTITLEMENT_IDS,
    );
    if (revenueCat.status === "verified" && revenueCat.active) {
      billingConnected = true;
      tier = "pro";
      entitlements = entitlementsForTier("pro");
      if (resolved.tier !== "pro") source = "revenuecat";
      verifiedAt = new Date(revenueCat.checkedAt).toISOString();
      expirationDate = revenueCat.periodEnd;
      accessKind = revenueCat.lifetime ? "legacyGrandfathered" : "pro";
      subscriptionState = revenueCat.lifetime
        ? "legacyGrandfathered"
        : "active";
    } else if (revenueCat.status === "verified" && resolved.tier !== "pro") {
      billingConnected = true;
      source = "revenuecat_inactive";
      verifiedAt = new Date(revenueCat.checkedAt).toISOString();
      accessKind = "free";
      subscriptionState = "free";
    } else if (revenueCat.status === "verified") {
      billingConnected = true;
      verifiedAt = new Date(revenueCat.checkedAt).toISOString();
    } else if (resolved.tier !== "pro") {
      billingConnected = false;
      source = "revenuecat_unavailable";
      verification = "unavailable";
      verifiedAt = null;
    }
  }

  return NextResponse.json({
    tier,
    entitlements,
    source,
    billingConnected,
    verification,
    verifiedAt,
    expirationDate,
    accessKind,
    subscriptionState,
    previewMode: false,
    founderPreview: false,
  });
}
