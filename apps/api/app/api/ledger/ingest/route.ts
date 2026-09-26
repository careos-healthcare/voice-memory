import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { replaceJournalTranscript } from "@/src/services/ledger/ingest";
import { parseLedgerIngestBody } from "@/src/services/ledger/ingest_request";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger/ingest",
      });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/ingest",
        internalCategory: "validation",
      });
    }

    const parsed = parseLedgerIngestBody(body);
    if (!parsed) {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/ingest",
        internalCategory: "validation",
      });
    }

    const stored = await replaceJournalTranscript(
      session.userId,
      parsed.entryId,
      parsed.transcript,
    );
    return NextResponse.json({
      ok: true,
      id: stored.id,
      entryId: stored.entryId,
    });
  } catch (error) {
    console.error("ledger/ingest failed", error);
    return apiErrorFromException(error, {
      code: "INTERNAL_ERROR",
      route: "ledger/ingest",
      logEvent: "api_error",
    });
  }
}
