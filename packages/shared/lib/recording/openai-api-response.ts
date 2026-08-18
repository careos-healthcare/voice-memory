/** Map OpenAI route error payloads to calm, non-technical copy. */
export function friendlyOpenAiApiError(
  status: number,
  body: { code?: string; error?: string | { code?: string; message?: string } },
  fallback: string,
): string {
  const nested =
    body.error && typeof body.error === "object" && body.error !== null
      ? body.error
      : null;
  const code = nested?.code ?? body.code;
  const errorMessage =
    nested?.message ?? (typeof body.error === "string" ? body.error : undefined);

  if (errorMessage?.trim()) {
    if (
      status === 429 ||
      code === "OPENAI_BUDGET_EXCEEDED" ||
      code === "OPENAI_PLATFORM_LIMIT" ||
      code === "OPENAI_DISABLED" ||
      code === "RATE_LIMIT_DAILY" ||
      code === "RATE_LIMIT_MINUTE"
    ) {
      return errorMessage;
    }
  }

  if (status === 429) {
    return "Voice processing is temporarily limited. Please try again later.";
  }

  if (
    status === 401 &&
    (code === "CAPTURE_AUTH_REQUIRED" ||
      code === "missing_capture_token" ||
      code === "unauthorized_capture_token")
  ) {
    return "Sign in or refresh this device, then try recording again.";
  }

  if (status >= 500) {
    return "Voice processing is temporarily unavailable. Please try again later.";
  }

  return fallback;
}
