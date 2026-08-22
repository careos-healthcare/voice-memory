import { NextResponse } from "next/server";

import { apiErrorResponse } from "@/lib/server/api-error-response";
import { handleCaregiverConsentRenewal } from "@/lib/server/consent-renewal-handler";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Issues a successor caregiver consent token at the archive owner's request.
 *
 * Unlike `revoke`, this route stays under the global rate limiter
 * (`apps/api/lib/rate-limit/constants.ts`). The exemption there exists because
 * a user ending someone's access must not be told to wait, and because the
 * limiter turns a cache outage into a 503 on every limited path. Neither
 * argument transfers: renewal continues access rather than ending it, so being
 * told to try again in a minute costs a delay in a window measured in days,
 * and an outage that blocks renewal leaves the grant to lapse — the direction
 * this design already prefers.
 */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "coach/consent/renew",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "coach/consent/renew",
      internalCategory: "validation",
    });
  }

  const result = await handleCaregiverConsentRenewal({
    sessionUserId: session.userId,
    body,
  });

  if (!result.ok) {
    return apiErrorResponse({
      code: result.code,
      route: "coach/consent/renew",
      internalCategory:
        result.code === "FORBIDDEN"
          ? "forbidden"
          : result.code === "CONSENT_RENEWAL_FAILED"
            ? "internal_error"
            : result.code === "GRANT_EXPIRED" ||
                result.code === "GRANT_NOT_RENEWABLE"
              ? "conflict"
              : "validation",
    });
  }

  return NextResponse.json({
    ok: true,
    renewed: true,
    consentDomain: "caregiverMonitoring",
    token: result.token,
    previousTokenId: result.previousTokenId,
    previousRevokedAt: result.previousRevokedAt,
    ownerConfirmedAt: result.ownerConfirmedAt,
  });
}
