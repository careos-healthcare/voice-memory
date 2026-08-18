import { randomBytes } from "node:crypto";

import {
  resolvePublicApiError,
  type PublicApiErrorCode,
} from "@/lib/server/public-api-error-codes";

export interface ApiErrorEnvelope {
  error: {
    code: string;
    message: string;
    retryable: boolean;
    requestId: string;
  };
}

export type InternalErrorCategory =
  | "validation"
  | "unauthenticated"
  | "forbidden"
  | "rate_limited"
  | "upstream_unavailable"
  | "conflict"
  | "database_unavailable"
  | "auth_secret_unconfigured"
  | "internal_error";

export function generateApiRequestId(scope = "api"): string {
  return `${scope}_${randomBytes(8).toString("hex")}`;
}

export function buildApiErrorEnvelope(input: {
  code: PublicApiErrorCode | string;
  message?: string;
  status?: number;
  retryable?: boolean;
  requestId?: string;
}): { body: ApiErrorEnvelope; status: number; requestId: string } {
  const resolved = resolvePublicApiError(input.code, {
    message: input.message,
    retryable: input.retryable,
    httpStatus: input.status,
  });
  const requestId = input.requestId ?? generateApiRequestId();
  return {
    requestId,
    status: resolved.httpStatus,
    body: {
      error: {
        code: resolved.code,
        message: resolved.message,
        retryable: resolved.retryable,
        requestId,
      },
    },
  };
}

export function classifyInternalException(error: unknown): InternalErrorCategory {
  const message =
    error instanceof Error
      ? error.message.toLowerCase()
      : typeof error === "string"
        ? error.toLowerCase()
        : "";

  if (
    message.includes("unauthorized") ||
    message.includes("sign in") ||
    message.includes("auth required")
  ) {
    return "unauthenticated";
  }
  if (message.includes("forbidden") || message.includes("permission")) {
    return "forbidden";
  }
  if (message.includes("rate limit") || message.includes("too many requests")) {
    return "rate_limited";
  }
  if (message.includes("conflict") || message.includes("already exists")) {
    return "conflict";
  }
  if (
    message.includes("econnrefused") ||
    message.includes("etimedout") ||
    message.includes("upstream") ||
    message.includes("service unavailable")
  ) {
    return "upstream_unavailable";
  }
  if (message.includes("database") || message.includes("postgres")) {
    return "database_unavailable";
  }
  if (message.includes("auth_secret")) {
    return "auth_secret_unconfigured";
  }
  if (message.includes("validation") || message.includes("invalid")) {
    return "validation";
  }
  return "internal_error";
}

const CATEGORY_TO_CODE: Record<InternalErrorCategory, PublicApiErrorCode | string> = {
  validation: "VALIDATION_ERROR",
  unauthenticated: "AUTH_REQUIRED",
  forbidden: "FORBIDDEN",
  rate_limited: "RATE_LIMIT_MINUTE",
  upstream_unavailable: "UPSTREAM_UNAVAILABLE",
  conflict: "CONFLICT",
  database_unavailable: "UPSTREAM_UNAVAILABLE",
  auth_secret_unconfigured: "INTERNAL_ERROR",
  internal_error: "INTERNAL_ERROR",
};

export function mapInternalCategoryToPublicCode(
  category: InternalErrorCategory,
): PublicApiErrorCode | string {
  return CATEGORY_TO_CODE[category];
}

export function buildApiErrorFromException(
  error: unknown,
  input: {
    code?: PublicApiErrorCode | string;
    message?: string;
    status?: number;
    requestId?: string;
  } = {},
): {
  body: ApiErrorEnvelope;
  status: number;
  requestId: string;
  internalCategory: InternalErrorCategory;
  code: string;
} {
  const internalCategory = classifyInternalException(error);
  const code = input.code ?? mapInternalCategoryToPublicCode(internalCategory);
  const built = buildApiErrorEnvelope({
    code,
    message: input.message,
    status: input.status,
    requestId: input.requestId,
  });
  return {
    ...built,
    internalCategory,
    code,
  };
}

export function bodyContainsSentinel(body: string, sentinel: string): boolean {
  return body.includes(sentinel);
}
