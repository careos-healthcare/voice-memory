import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { deleteUserLedger } from "@/src/services/ledger/delete_user_ledger";

export const runtime = "nodejs";

export async function DELETE() {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger/user",
      });
    }

    const deleted = await deleteUserLedger(session.userId);
    return NextResponse.json({ ok: true, deleted });
  } catch (error) {
    console.error("ledger/user delete failed", error);
    return apiErrorFromException(error, {
      code: "INTERNAL_ERROR",
      route: "ledger/user",
      logEvent: "api_error",
    });
  }
}
