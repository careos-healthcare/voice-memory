import { NextResponse } from "next/server";

import { apiErrorResponse } from "@/lib/server/api-error-response";
import { handleConsentRevocation } from "@/lib/server/consent-revoke-handler";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Records a server-side revocation for a consent grant.
 *
 * This route is exempt from the global rate limiter
 * (`apps/api/lib/rate-limit/constants.ts`). A user who has decided to end
 * someone's access to their journal must not be told to wait a minute, and the
 * limiter itself returns 503 for every path when Redis is down — which would
 * make an unrelated cache outage into an inability to revoke. The route is
 * session-gated and the work it does is one idempotent upsert.
 */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "coach/consent/revoke",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "coach/consent/revoke",
      internalCategory: "validation",
    });
  }

  const result = await handleConsentRevocation({
    sessionUserId: session.userId,
    body,
  });

  if (!result.ok) {
    return apiErrorResponse({
      code: result.code,
      route: "coach/consent/revoke",
      internalCategory:
        result.code === "FORBIDDEN"
          ? "forbidden"
          : result.code === "INVALID_TOKEN_ID"
            ? "validation"
            : "internal_error",
    });
  }

  return NextResponse.json({
    ok: true,
    revoked: true,
    tokenId: result.tokenId,
    consentDomain: result.grantKind,
    revokedAt: result.revokedAt,
    alreadyRevoked: result.alreadyRevoked,
  });
}
