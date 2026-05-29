import { NextResponse } from "next/server";

import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import { resolveServerEntitlements } from "@/lib/server/billing-entitlements";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/** Server-backed entitlements for signed-in users. */
export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
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
