import "server-only";

import { NextResponse } from "next/server";

import {
  buildApiErrorEnvelope,
  buildApiErrorFromException,
  generateApiRequestId,
  type ApiErrorEnvelope,
  type InternalErrorCategory,
} from "@/lib/server/api-error-core";
export {
  bodyContainsSentinel,
  buildApiErrorEnvelope,
  classifyInternalException,
  generateApiRequestId,
  mapInternalCategoryToPublicCode,
  type ApiErrorEnvelope,
  type InternalErrorCategory,
} from "@/lib/server/api-error-core";
import { PUBLIC_API_ERROR_CODES, type PublicApiErrorCode } from "@/lib/server/public-api-error-codes";
import { logServerEvent, type LogEvent } from "@/lib/server/structured-log";

export function apiErrorResponse(input: {
  code: PublicApiErrorCode | string;
  message?: string;
  status?: number;
  retryable?: boolean;
  requestId?: string;
  logEvent?: LogEvent;
  internalCategory?: InternalErrorCategory;
  route?: string;
}): NextResponse {
  const built = buildApiErrorEnvelope(input);
  if (input.logEvent) {
    logServerEvent(input.logEvent, {
      requestId: built.requestId,
      errorCode: built.body.error.code,
      internalCategory: input.internalCategory ?? "internal_error",
      httpStatus: built.status,
      route: input.route ?? null,
    });
  }
  return NextResponse.json(built.body, { status: built.status });
}

export function apiErrorFromException(
  error: unknown,
  input: {
    code?: PublicApiErrorCode | string;
    message?: string;
    status?: number;
    requestId?: string;
    logEvent?: LogEvent;
    route?: string;
  } = {},
): NextResponse {
  const built = buildApiErrorFromException(error, input);
  logServerEvent(input.logEvent ?? "api_error", {
    requestId: built.requestId,
    errorCode: built.code,
    internalCategory: built.internalCategory,
    route: input.route ?? null,
  });
  return NextResponse.json(built.body, { status: built.status });
}

export async function readApiErrorBody(response: NextResponse): Promise<string> {
  return response.text();
}

export function apiMethodNotAllowed(input: {
  route: string;
  methods: string[];
  message: string;
  extra?: Record<string, unknown>;
}): NextResponse {
  const built = buildApiErrorEnvelope({
    code: "METHOD_NOT_ALLOWED",
    message: input.message,
    status: 405,
  });
  return NextResponse.json(
    { ...built.body, route: input.route, methods: input.methods, ...input.extra },
    { status: 405 },
  );
}

export { PUBLIC_API_ERROR_CODES };
