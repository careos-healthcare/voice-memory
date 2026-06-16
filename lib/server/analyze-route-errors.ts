import "server-only";

import { NextResponse } from "next/server";

export type AnalyzeRouteFailureCode =
  | "missing_openai_key"
  | "missing_capture_token"
  | "unauthorized_capture_token"
  | "model_error"
  | "invalid_request_body"
  | "invalid_reflection"
  | "transcript_required"
  | "transcript_too_long"
  | "route_not_found"
  | "ANALYZE_UNAVAILABLE"
  | "OPENAI_DISABLED"
  | "OPENAI_BUDGET_EXCEEDED"
  | "OPENAI_PLATFORM_LIMIT"
  | "RATE_LIMIT_MINUTE"
  | "RATE_LIMIT_DAILY"
  | "CAPTURE_AUTH_REQUIRED";

const LOG_PREFIX = "ARCHIVEME_ANALYZE";

export function logAnalyzeStep(message: string): void {
  console.info(`${LOG_PREFIX}_STEP ${message}`);
}

export function logAnalyzeFailure(code: string, reason: string): void {
  console.error(`${LOG_PREFIX}_FAILED code=${code} reason=${reason}`);
}

export function analyzeRouteErrorResponse(
  code: AnalyzeRouteFailureCode,
  message: string,
  status: number,
  extra?: Record<string, unknown>,
): NextResponse {
  logAnalyzeFailure(code, message);
  return NextResponse.json({ error: message, code, ...extra }, { status });
}

export function classifyAnalyzeRouteError(error: unknown): {
  code: AnalyzeRouteFailureCode;
  message: string;
  status: number;
} {
  if (!process.env.OPENAI_API_KEY?.trim()) {
    return {
      code: "missing_openai_key",
      message: "Analysis is not configured on the server.",
      status: 503,
    };
  }

  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("openapi_api_key") || lower.includes("openai_api_key")) {
    return {
      code: "missing_openai_key",
      message: "Analysis is not configured on the server.",
      status: 503,
    };
  }

  if (error instanceof SyntaxError || lower.includes("json")) {
    return {
      code: "model_error",
      message: "Analysis model returned an unreadable response.",
      status: 502,
    };
  }

  if (
    lower.includes("invalid reflection") ||
    lower.includes("therapy") ||
    lower.includes("generic therapy")
  ) {
    return {
      code: "invalid_reflection",
      message: "Analysis model returned an invalid reflection.",
      status: 502,
    };
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "status" in error &&
    typeof (error as { status?: unknown }).status === "number"
  ) {
    return {
      code: "model_error",
      message: "Analysis model request failed.",
      status: 502,
    };
  }

  return {
    code: "model_error",
    message: "Analysis could not be completed.",
    status: 502,
  };
}
