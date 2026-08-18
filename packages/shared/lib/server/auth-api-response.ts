import { NextResponse } from "next/server";

import { apiErrorFromException, apiErrorResponse } from "@/lib/server/api-error-response";
import type { AuthErrorCode } from "@/types/auth-errors";

export function authApiSuccess<T extends Record<string, unknown>>(
  data: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ ok: true, ...data }, { status });
}

export function authApiFailure(
  code: AuthErrorCode | string,
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
      route: "auth",
    });
  }

  return apiErrorResponse({
    code,
    message: options?.message,
    status: options?.status,
    requestId: options?.requestId,
    logEvent: "api_error",
    internalCategory: "validation",
    route: "auth",
  });
}
