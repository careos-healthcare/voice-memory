import { NextResponse } from "next/server";

import { isGeminiConfigured } from "@/lib/gemini";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import {
  postBulkImportAudio,
  postBulkImportJson,
  type BulkImportJsonRequestBody,
} from "@/src/routes/ledger/bulk_import";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    if (!isGeminiConfigured()) {
      return apiErrorResponse({ code: "GEMINI_NOT_CONFIGURED", route: "ledger/bulk-import" });
    }

    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "ledger/bulk-import",
      });
    }

    const contentType = request.headers.get("content-type") ?? "";
    if (contentType.includes("multipart/form-data")) {
      const formData = await request.formData();
      const result = await postBulkImportAudio(session.userId, formData, request);
      if (!result.ok) {
        return apiErrorResponse({
          code: result.code,
          status: result.status,
          route: "ledger/bulk-import",
        });
      }
      return NextResponse.json(result);
    }

    let body: BulkImportJsonRequestBody;
    try {
      body = (await request.json()) as BulkImportJsonRequestBody;
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "ledger/bulk-import",
        internalCategory: "validation",
      });
    }

    const result = await postBulkImportJson(session.userId, body);
    if (!result.ok) {
      return apiErrorResponse({
        code: result.code,
        status: result.status,
        route: "ledger/bulk-import",
      });
    }

    return NextResponse.json(result);
  } catch (error) {
    console.error("ledger/bulk-import failed", error);
    return apiErrorFromException(error, {
      code: "BULK_IMPORT_FAILED",
      route: "ledger/bulk-import",
      logEvent: "api_error",
    });
  }
}
