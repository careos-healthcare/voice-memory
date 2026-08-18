import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import {
  deleteUserServerData,
  revokeAllSessionsForUser,
} from "@/lib/server/account-deletion";
import type { StoreDeletionResult } from "@/lib/server/account-deletion-contract";
import { SESSION_COOKIE } from "@/lib/server/auth-crypto";
import {
  apiErrorResponse,
  generateApiRequestId,
} from "@/lib/server/api-error-response";
import {
  clearSessionCookie,
  getServerSession,
} from "@/lib/server/session";
import { logServerEvent } from "@/lib/server/structured-log";

export const runtime = "nodejs";

function sanitizeStoresForClient(stores: StoreDeletionResult[]) {
  return stores.map((store) => ({
    store: store.store,
    mode: store.mode,
    ok: store.ok,
    ...(store.count !== undefined ? { count: store.count } : {}),
  }));
}

export async function POST(request: Request) {
  const requestId = generateApiRequestId("account_delete");
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      message: "Sign in required to delete server account data.",
      requestId,
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "account/delete",
    });
  }

  let confirm = false;
  try {
    const body = (await request.json()) as { confirm?: boolean };
    confirm = body.confirm === true;
  } catch {
    confirm = false;
  }

  if (!confirm) {
    return apiErrorResponse({
      code: "CONFIRM_REQUIRED",
      requestId,
      internalCategory: "validation",
      route: "account/delete",
    });
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value ?? "";

  const result = await deleteUserServerData(session.userId, session.email);

  let sessionRevokeFailed = false;
  try {
    await revokeAllSessionsForUser(session.userId, token);
  } catch (error) {
    sessionRevokeFailed = true;
    logServerEvent("account_deletion", {
      requestId,
      errorCode: "SESSION_REVOKE_FAILED",
      internalCategory: "internal_error",
      route: "account/delete",
    });
  }

  const ok = result.ok && !sessionRevokeFailed;
  const stores = sanitizeStoresForClient(result.stores);

  if (!ok) {
    const code = sessionRevokeFailed && result.ok ? "SESSION_REVOKE_FAILED" : "ACCOUNT_DELETE_PARTIAL";
    logServerEvent("account_deletion", {
      requestId,
      errorCode: code,
      internalCategory: "internal_error",
      route: "account/delete",
      partial: true,
    });

    const response = NextResponse.json(
      {
        ok: false,
        stores,
        error: {
          code,
          message:
            code === "SESSION_REVOKE_FAILED"
              ? "Account data was removed but the active session could not be revoked."
              : "Server account data deletion was only partially completed. Some data may remain — contact support if this persists.",
          retryable: false,
          requestId,
        },
        message:
          "Server account data deletion was only partially completed. Some data may remain — contact support if this persists.",
      },
      { status: 207 },
    );
    response.cookies.set(clearSessionCookie());
    return response;
  }

  const response = NextResponse.json({
    ok: true,
    stores,
    message:
      "Server account data removed. Clear local data on this device from Settings if you have not already.",
  });
  response.cookies.set(clearSessionCookie());
  return response;
}
