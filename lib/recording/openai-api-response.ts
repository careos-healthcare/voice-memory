/** Map OpenAI route error payloads to calm, non-technical copy. */
export function friendlyOpenAiApiError(
  status: number,
  body: { code?: string; error?: string },
  fallback: string,
): string {
  if (typeof body.error === "string" && body.error.trim()) {
    if (
      status === 429 ||
      body.code === "OPENAI_BUDGET_EXCEEDED" ||
      body.code === "OPENAI_PLATFORM_LIMIT" ||
      body.code === "OPENAI_DISABLED" ||
      body.code === "RATE_LIMIT_DAILY" ||
      body.code === "RATE_LIMIT_MINUTE"
    ) {
      return body.error;
    }
  }

  if (status === 429) {
    return "Voice processing is temporarily limited. Please try again later.";
  }

  if (status === 401 && (body.code === "CAPTURE_AUTH_REQUIRED" || body.code === "missing_capture_token" || body.code === "unauthorized_capture_token")) {
    return "Sign in or refresh this device, then try recording again.";
  }

  if (status >= 500) {
    return "Voice processing is temporarily unavailable. Please try again later.";
  }

  return fallback;
}
