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
  | "CAPTURE_AUTH_REQUIRED"
  | "service_unavailable";

export const ANALYZE_UNAVAILABLE_MESSAGE =
  "Voice processing is temporarily unavailable. Please try again later.";

function openAiHttpStatus(error: unknown): number | null {
  if (typeof error !== "object" || error === null || !("status" in error)) {
    return null;
  }
  const status = (error as { status?: unknown }).status;
  return typeof status === "number" ? status : null;
}

function isInfrastructureError(message: string): boolean {
  const lower = message.toLowerCase();
  return (
    lower.includes("auth_secret") ||
    lower.includes("database_url") ||
    lower.includes("database") ||
    lower.includes("postgres") ||
    lower.includes("connection terminated") ||
    lower.includes("econnrefused") ||
    lower.includes("etimedout") ||
    lower.includes("connection timeout") ||
    lower.includes("getaddrinfo")
  );
}

export function classifyAnalyzeRouteError(
  error: unknown,
  options?: { openAiKeyPresent?: boolean; production?: boolean },
): {
  code: AnalyzeRouteFailureCode;
  message: string;
  status: number;
} {
  const openAiKeyPresent =
    options?.openAiKeyPresent ??
    Boolean(process.env.OPENAI_API_KEY?.trim());

  if (!openAiKeyPresent) {
    return {
      code: "missing_openai_key",
      message: "Analysis is not configured on the server.",
      status: 503,
    };
  }

  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();
  const httpStatus = openAiHttpStatus(error);

  if (
    lower.includes("openai_api_key") ||
    lower.includes("incorrect api key") ||
    lower.includes("invalid api key") ||
    httpStatus === 401
  ) {
    return {
      code: "missing_openai_key",
      message: "Analysis is not configured on the server.",
      status: 503,
    };
  }

  if (isInfrastructureError(message)) {
    return {
      code: "service_unavailable",
      message: "Analysis storage is temporarily unavailable.",
      status: 503,
    };
  }

  if (httpStatus === 429) {
    return {
      code: "ANALYZE_UNAVAILABLE",
      message: ANALYZE_UNAVAILABLE_MESSAGE,
      status: 429,
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

  if (httpStatus != null) {
    return {
      code: "ANALYZE_UNAVAILABLE",
      message: ANALYZE_UNAVAILABLE_MESSAGE,
      status: httpStatus >= 500 ? 502 : httpStatus,
    };
  }

  return {
    code: "ANALYZE_UNAVAILABLE",
    message: ANALYZE_UNAVAILABLE_MESSAGE,
    status: 502,
  };
}

export function analyzeRouteClientError(
  error: unknown,
  options?: { openAiKeyPresent?: boolean; production?: boolean },
): {
  code: AnalyzeRouteFailureCode;
  message: string;
  status: number;
} {
  const production = options?.production ?? process.env.NODE_ENV === "production";
  const classified = classifyAnalyzeRouteError(error, options);

  if (!production) {
    return classified;
  }

  if (classified.code === "missing_openai_key") {
    return classified;
  }

  return {
    code: "ANALYZE_UNAVAILABLE",
    message: ANALYZE_UNAVAILABLE_MESSAGE,
    status: classified.status,
  };
}
