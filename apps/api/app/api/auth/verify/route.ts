import { NextResponse } from "next/server";

import { logAuthError, isPostgresAuthError } from "@/lib/server/auth-diagnostics";
import { verifyEmailLoginCode } from "@/lib/server/auth-store";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import {
  buildSessionCookie,
  createSessionTokenForUser,
  persistSessionForUser,
} from "@/lib/server/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { email?: string; code?: string };
    const email = body.email?.trim();
    const code = body.code?.trim();
    if (!email || !code) {
      return apiErrorResponse({
        code: "AUTH_CODE_REQUIRED",
        route: "auth/verify",
        internalCategory: "validation",
      });
    }

    const user = await verifyEmailLoginCode(email, code);
    if (!user) {
      return apiErrorResponse({
        code: "AUTH_CODE_INVALID",
        route: "auth/verify",
        internalCategory: "unauthenticated",
      });
    }

    const token = createSessionTokenForUser(user);
    await persistSessionForUser(token, user);
    const response = NextResponse.json({
      session: {
        user: { id: user.id, email: user.email },
        signedInAt: new Date().toISOString(),
      },
    });
    response.cookies.set(buildSessionCookie(token));
    return response;
  } catch (error) {
    if (isPostgresAuthError(error)) {
      logAuthError("verify", error, { phase: "postgres_verify" });
      return apiErrorResponse({
        code: "AUTH_DATABASE_FAILED",
        route: "auth/verify",
        logEvent: "auth_failure",
        internalCategory: "database_unavailable",
      });
    }
    logAuthError("verify", error);
    return apiErrorFromException(error, {
      code: "AUTH_VERIFY_FAILED",
      route: "auth/verify",
      logEvent: "auth_failure",
    });
  }
}
