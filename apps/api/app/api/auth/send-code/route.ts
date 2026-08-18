import { AuthRateLimitError, recordSendCodeIpHit } from "@/lib/auth/auth-code-policy";
import { authApiFailure, authApiSuccess } from "@/lib/server/auth-api-response";
import { createAuthSendCodeLog, hashEmailForLog } from "@/lib/server/auth-route-log";
import { ipHashFromRequest } from "@/lib/server/request-identity";
import {
  isPostgresAuthError,
  logAuthError,
} from "@/lib/server/auth-diagnostics";
import { readAuthEmailEnvStatus } from "@/lib/server/env-check";
import {
  AuthEmailError,
  sendAuthCodeEmail,
} from "@/lib/email/send-auth-code";
import { AuthStorageNotConfiguredError, issueEmailLoginCode } from "@/lib/server/auth-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const { requestId, log, finalize } = createAuthSendCodeLog();
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
      return authApiFailure("AUTH_INVALID_REQUEST", {
        message: "Request body is required.",
        status: 400,
        requestId,
      });
    }
    body = JSON.parse(raw) as { email?: string };
  } catch (error) {
    log({ ok: false, errorCode: "AUTH_INVALID_REQUEST", stack: error instanceof Error ? error.stack ?? null : null });
    finalize(error);
    return authApiFailure("AUTH_INVALID_REQUEST", { status: 400, requestId, cause: error });
  }

  const email = body.email?.trim();
  if (!email) {
    log({ ok: false, errorCode: "AUTH_EMAIL_REQUIRED" });
    finalize();
    return authApiFailure("AUTH_EMAIL_REQUIRED", { status: 400, requestId });
  }

  log({ emailHash: hashEmailForLog(email) });

  if (!recordSendCodeIpHit(ipHashFromRequest(request), Date.now())) {
    log({ ok: false, errorCode: "AUTH_RATE_LIMITED" });
    finalize();
    return authApiFailure("AUTH_RATE_LIMITED", { status: 429, requestId });
  }

  try {
    const { code } = await issueEmailLoginCode(email);

    if (process.env.NODE_ENV !== "production") {
      console.info(`[ArchiveMe auth] Sign-in code for ${email}: ${code}`);
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
    if (error instanceof AuthRateLimitError) {
      log({ ok: false, errorCode: "AUTH_RATE_LIMITED" });
      finalize();
      return authApiFailure("AUTH_RATE_LIMITED", {
        message: "A code was sent recently. Check your email or try again in a minute.",
        status: 429,
        requestId,
      });
    }

    if (error instanceof AuthStorageNotConfiguredError) {
      log({ ok: false, errorCode: "AUTH_STORAGE_NOT_CONFIGURED" });
      finalize(error);
      return authApiFailure("AUTH_STORAGE_NOT_CONFIGURED", { status: 503, requestId, cause: error });
    }

    if (isPostgresAuthError(error)) {
      logAuthError("send-code", error, { phase: "postgres_auth_code" });
      log({ ok: false, errorCode: "AUTH_DATABASE_FAILED" });
      finalize(error);
      return authApiFailure("AUTH_DATABASE_FAILED", { status: 503, requestId, cause: error });
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

      return authApiFailure(error.code, { status, requestId });
    }

    log({
      ok: false,
      errorCode: "AUTH_EMAIL_SEND_FAILED",
      stack: error instanceof Error ? error.stack ?? null : null,
      resendErrorMessage: error instanceof Error ? error.message : String(error),
    });
    finalize(error);
    return authApiFailure("AUTH_EMAIL_SEND_FAILED", {
      status: 502,
      requestId,
      cause: error,
    });
  }
}
