import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { deleteLedgerLabel } from "@/src/services/ledger/delete_ledger_label";
import { parseLedgerEntityDelete } from "@/src/services/ledger/entity_request";

export const runtime = "nodejs";

export async function DELETE(request: Request) {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger/entity",
      });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/entity",
        internalCategory: "validation",
      });
    }

    const parsed = parseLedgerEntityDelete(body);
    if (!parsed) {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/entity",
        internalCategory: "validation",
      });
    }

    const deleted = await deleteLedgerLabel(session.userId, parsed.label);
    return NextResponse.json({ ok: true, deleted });
  } catch (error) {
    console.error("ledger/entity delete failed", error);
    return apiErrorFromException(error, {
      code: "INTERNAL_ERROR",
      route: "ledger/entity",
      logEvent: "api_error",
    });
  }
}
