import "server-only";

import { NextResponse } from "next/server";

import { getRevenueCatUserMapping } from "@/lib/server/revenuecat-mapping";
import {
  REVENUECAT_PRO_ENTITLEMENT_IDS,
  verifyRevenueCatEntitlement,
  type RevenueCatVerification,
} from "@/lib/server/revenuecat-verifier";

export interface RevenueCatEntitlementContext {
  userId: string;
  appUserId: string;
  requiredEntitlementIds: readonly string[];
  verificationSource: "revenuecat" | "cache";
}

export type RevenueCatEntitlementGuardResult =
  | { ok: true; ctx: RevenueCatEntitlementContext }
  | { ok: false; response: NextResponse };

function failure(
  status: 401 | 403 | 409 | 503,
  code:
    | "AUTH_REQUIRED"
    | "REVENUECAT_MAPPING_REQUIRED"
    | "ENTITLEMENT_REQUIRED"
    | "ENTITLEMENT_VERIFICATION_UNAVAILABLE",
  error: string,
): RevenueCatEntitlementGuardResult {
  return {
    ok: false,
    response: NextResponse.json({ error, code }, { status }),
  };
}

export async function requireRevenueCatEntitlement(
  authenticatedUserId: string | null | undefined,
  requiredEntitlementIds: readonly string[] = REVENUECAT_PRO_ENTITLEMENT_IDS,
  dependencies?: {
    getMapping?: typeof getRevenueCatUserMapping;
    verify?: (
      appUserId: string,
      requiredIds: readonly string[],
    ) => Promise<RevenueCatVerification>;
  },
): Promise<RevenueCatEntitlementGuardResult> {
  if (!authenticatedUserId) {
    return failure(401, "AUTH_REQUIRED", "Sign in required.");
  }

  const mapping = await (dependencies?.getMapping ?? getRevenueCatUserMapping)(
    authenticatedUserId,
  );
  if (!mapping) {
    return failure(
      409,
      "REVENUECAT_MAPPING_REQUIRED",
      "Connect this account to App Store billing.",
    );
  }

  const verification = await (
    dependencies?.verify ?? verifyRevenueCatEntitlement
  )(mapping.appUserId, requiredEntitlementIds);
  if (verification.status === "unavailable") {
    return failure(
      503,
      "ENTITLEMENT_VERIFICATION_UNAVAILABLE",
      "Purchase verification is temporarily unavailable.",
    );
  }
  if (!verification.active) {
    return failure(
      403,
      "ENTITLEMENT_REQUIRED",
      "An active Pro entitlement is required.",
    );
  }

  return {
    ok: true,
    ctx: {
      userId: authenticatedUserId,
      appUserId: mapping.appUserId,
      requiredEntitlementIds,
      verificationSource: verification.source,
    },
  };
}

export function authenticatedUserIdMismatchResponse(
  claimedUserId: unknown,
  authenticatedUserId: string,
): NextResponse | null {
  if (typeof claimedUserId !== "string" || claimedUserId !== authenticatedUserId) {
    return NextResponse.json(
      {
        error: "Request user does not match the authenticated session.",
        code: "USER_ID_MISMATCH",
      },
      { status: 403 },
    );
  }
  return null;
}
