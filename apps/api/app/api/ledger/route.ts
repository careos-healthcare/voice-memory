import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { deleteUserLedger } from "@/src/services/ledger/delete_user_ledger";

export const runtime = "nodejs";

/** Deletes every fact-ledger row for the signed-in person. */
export async function DELETE() {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger",
      });
    }

    const deleted = await deleteUserLedger(session.userId);
    return NextResponse.json({ ok: true, deleted });
  } catch (error) {
    console.error("ledger delete failed", error);
    return apiErrorFromException(error, {
      code: "INTERNAL_ERROR",
      route: "ledger",
      logEvent: "api_error",
    });
  }
}
