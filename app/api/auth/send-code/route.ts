import { authApiFailure, authApiSuccess } from "@/lib/server/auth-api-response";
import { createAuthSendCodeLog } from "@/lib/server/auth-route-log";
import { readAuthEmailEnvStatus } from "@/lib/server/env-check";
import {
  AuthEmailError,
  sendAuthCodeEmail,
} from "@/lib/email/send-auth-code";
import { AuthStorageNotConfiguredError, issueEmailLoginCode } from "@/lib/server/auth-store";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const { log, finalize } = createAuthSendCodeLog();
  const envStatus = readAuthEmailEnvStatus();

  log({
    apiKeyPresent: envStatus.resendConfigured,
    emailFromPresent: envStatus.emailFromConfigured,
    appUrlPresent: envStatus.appUrlConfigured,
  });

  let body: { email?: string };
  try {
    const raw = await request.text();
    if (!raw.trim()) {
      log({ ok: false, errorCode: "AUTH_INVALID_REQUEST" });
      finalize();
      return authApiFailure("Request body is required.", "AUTH_INVALID_REQUEST", 400);
    }
    body = JSON.parse(raw) as { email?: string };
  } catch (error) {
    log({ ok: false, errorCode: "AUTH_INVALID_REQUEST", stack: error instanceof Error ? error.stack ?? null : null });
    finalize(error);
    return authApiFailure("Request body must be valid JSON.", "AUTH_INVALID_REQUEST", 400);
  }

  const email = body.email?.trim();
  if (!email) {
    log({ ok: false, errorCode: "AUTH_EMAIL_REQUIRED" });
    finalize();
    return authApiFailure("Email is required.", "AUTH_EMAIL_REQUIRED", 400);
  }

  log({ email });

  try {
    const { code } = issueEmailLoginCode(email);

    if (process.env.NODE_ENV !== "production") {
      console.info(`[VoiceMemory auth] Sign-in code for ${email}: ${code}`);
      log({ ok: true, resendInitialized: false });
      finalize();
      return authApiSuccess({
        message: "Code sent. Check your email.",
        devCode: code,
      });
    }

    const sendResult = await sendAuthCodeEmail(email, code);
    log({
      ok: true,
      resendInitialized: sendResult.resendInitialized,
      emailFromPresent: sendResult.emailFromPresent,
      apiKeyPresent: sendResult.apiKeyPresent,
      resendResponseId: sendResult.resendResponseId,
      resendErrorName: sendResult.resendErrorName,
      resendErrorMessage: sendResult.resendErrorMessage,
    });
    finalize();

    return authApiSuccess({ message: "Code sent. Check your email." });
  } catch (error) {
    if (error instanceof AuthStorageNotConfiguredError) {
      log({ ok: false, errorCode: "AUTH_STORAGE_NOT_CONFIGURED" });
      finalize(error);
      return authApiFailure(
        "Auth storage is not configured.",
        "AUTH_STORAGE_NOT_CONFIGURED",
        503,
      );
    }

    if (error instanceof AuthEmailError) {
      log({
        ok: false,
        errorCode: error.code,
        resendErrorName: error.name,
        resendErrorMessage: error.message,
        stack: error.stack ?? null,
      });
      finalize(error);

      const status =
        error.code === "AUTH_RESEND_NOT_CONFIGURED"
          ? 503
          : error.code === "AUTH_INVALID_EMAIL_FROM" || error.code === "AUTH_RESEND_REJECTED"
            ? 502
            : 502;

      const userMessage =
        error.code === "AUTH_INVALID_EMAIL_FROM" || error.code === "AUTH_RESEND_REJECTED"
          ? "Auth email provider rejected the sender address."
          : error.code === "AUTH_RESEND_NOT_CONFIGURED"
            ? "Email delivery is temporarily unavailable."
            : "Email delivery is temporarily unavailable.";

      return authApiFailure(userMessage, error.code, status);
    }

    log({
      ok: false,
      errorCode: "AUTH_EMAIL_SEND_FAILED",
      stack: error instanceof Error ? error.stack ?? null : null,
      resendErrorMessage: error instanceof Error ? error.message : String(error),
    });
    finalize(error);
    return authApiFailure(
      "Email delivery is temporarily unavailable.",
      "AUTH_EMAIL_SEND_FAILED",
      502,
    );
  }
}
