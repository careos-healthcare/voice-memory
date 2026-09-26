import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { deleteLedgerEntry } from "@/src/services/ledger/ingest";

export const runtime = "nodejs";

export async function DELETE(request: Request) {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger/entry",
      });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/entry",
        internalCategory: "validation",
      });
    }

    const entryId =
      body && typeof body === "object" && "entryId" in body
        ? String((body as { entryId?: unknown }).entryId ?? "").trim()
        : "";
    if (!entryId) {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/entry",
        internalCategory: "validation",
      });
    }

    const deleted = await deleteLedgerEntry(session.userId, entryId);
    return NextResponse.json({ ok: true, deleted });
  } catch (error) {
    console.error("ledger/entry delete failed", error);
    return apiErrorFromException(error, {
      code: "INTERNAL_ERROR",
      route: "ledger/entry",
      logEvent: "api_error",
    });
  }
}
