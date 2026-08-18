import { NextResponse } from "next/server";

import { apiErrorFromException, apiErrorResponse } from "@/lib/server/api-error-response";
import type { SyncErrorCode } from "@/types/sync-errors";

export function syncApiSuccess<T extends Record<string, unknown>>(
  data: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ ok: true, ...data }, { status });
}

export function syncApiFailure(
  code: SyncErrorCode | string,
  options?: {
    message?: string;
    status?: number;
    requestId?: string;
    cause?: unknown;
  },
): NextResponse {
  if (options?.cause) {
    return apiErrorFromException(options.cause, {
      code,
      message: options.message,
      status: options.status,
      requestId: options.requestId,
      route: "sync",
    });
  }

  return apiErrorResponse({
    code,
    message: options?.message,
    status: options?.status,
    requestId: options?.requestId,
    logEvent: "api_error",
    internalCategory: "validation",
    route: "sync",
  });
}

export function syncApiUnauthorized(requestId?: string): NextResponse {
  return syncApiFailure("SYNC_AUTH_REQUIRED", { requestId });
}
