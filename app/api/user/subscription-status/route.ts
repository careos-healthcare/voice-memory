import { NextResponse } from "next/server";

import { entitlementsForTier } from "@/lib/entitlement/tiers";
import {
  getServerBillingRecord,
  resolveServerEntitlements,
} from "@/lib/server/billing-entitlements";
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

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  }

  const [resolved, record, mapping, stripeState, revenueCatState] =
    await Promise.all([
      resolveServerEntitlements(session.userId),
      getServerBillingRecord(session.userId),
      getRevenueCatUserMapping(session.userId),
      getAuthoritativeEntitlementState(session.userId, "stripe"),
      getAuthoritativeEntitlementState(session.userId, "revenuecat"),
    ]);
  const hasAuthoritativeState =
    stripeState !== null || revenueCatState !== null;
  const revenueCat =
    mapping && !hasAuthoritativeState
      ? await verifyRevenueCatEntitlement(
          mapping.appUserId,
          REVENUECAT_PRO_ENTITLEMENT_IDS,
        )
      : null;
  const revenueCatActive =
    revenueCat?.status === "verified" && revenueCat.active;
  const authoritativeState = grantsPro(stripeState)
    ? stripeState
    : grantsPro(revenueCatState)
      ? revenueCatState
      : null;
  const stripeActive =
    grantsPro(stripeState) || (!stripeState && resolved.tier === "pro");
  const active =
    authoritativeState !== null ||
    (!hasAuthoritativeState && (stripeActive || revenueCatActive));
  const tier = active ? "pro" : "free";
  const source =
    authoritativeState?.provider ??
    (stripeActive
      ? "stripe"
      : revenueCatActive
        ? "revenuecat"
        : hasAuthoritativeState
          ? "authoritative_inactive"
          : "free_tier");
  const expirationDate =
    authoritativeState?.periodEnd ??
    (revenueCat?.status === "verified" ? revenueCat.periodEnd : null) ??
    record?.subscriptionEndDate ??
    null;
  const verification =
    hasAuthoritativeState || revenueCat?.status === "verified"
      ? "verified"
      : revenueCat?.status === "unavailable"
        ? "unavailable"
        : "not_configured";

  return NextResponse.json(
    {
      hasActiveSubscription: active,
      subscriptionStatus: active ? "active" : "inactive",
      providerStatus: record?.status ?? "canceled",
      subscriptionEndDate: expirationDate,
      expirationDate,
      tier,
      entitlements: entitlementsForTier(tier),
      source,
      billingConnected:
        record != null ||
        hasAuthoritativeState ||
        revenueCat?.status === "verified",
      verification,
      verifiedAt:
        authoritativeState?.updatedAt ??
        (revenueCat?.status === "verified" ? revenueCat.checkedAt : null),
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
