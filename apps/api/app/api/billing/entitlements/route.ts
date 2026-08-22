import { NextResponse } from "next/server";

import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import { resolveServerEntitlements } from "@/lib/server/billing-entitlements";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/** Server-backed entitlements for signed-in users. */
export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "billing/entitlements",
    });
  }

  const billingConnected = isLiveBillingAvailable();
  const resolved = await resolveServerEntitlements(session.userId);

  return NextResponse.json({
    tier: resolved.tier,
    entitlements: resolved.entitlements,
    source: resolved.source,
    billingConnected,
    previewMode: false,
    founderPreview: false,
  });
}
