import "server-only";

import { Resend } from "resend";

import { readAuthEmailEnvStatus } from "@/lib/server/env-check";
import type { AuthErrorCode } from "@/types/auth-errors";

const SUBJECT = "Your VoiceMemory sign-in code";

export class AuthEmailError extends Error {
  code: AuthErrorCode;

  constructor(code: AuthErrorCode, message: string) {
    super(message);
    this.name = "AuthEmailError";
    this.code = code;
  }
}

/** @deprecated Use AuthEmailError */
export class AuthEmailNotConfiguredError extends AuthEmailError {
  constructor(message: string) {
    super("AUTH_RESEND_NOT_CONFIGURED", message);
    this.name = "AuthEmailNotConfiguredError";
  }
}

/** @deprecated Use AuthEmailError */
export class AuthEmailDeliveryError extends AuthEmailError {
  constructor(code: AuthErrorCode, message: string) {
    super(code, message);
    this.name = "AuthEmailDeliveryError";
  }
}

export interface SendAuthCodeEmailResult {
  resendInitialized: boolean;
  emailFromPresent: boolean;
  apiKeyPresent: boolean;
  resendResponseId: string | null;
  resendErrorName: string | null;
  resendErrorMessage: string | null;
}

function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}

function buildEmailBody(code: string): string {
  return `Your VoiceMemory sign-in code is:

${code}

This code expires soon.
If you did not request this, you can ignore this email.`;
}

function isSenderRejection(message: string): boolean {
  return /from|sender|domain|not verified|invalid.*address/i.test(message);
}

/** Send the sign-in code through Resend in production. */
export async function sendAuthCodeEmail(
  email: string,
  code: string,
): Promise<SendAuthCodeEmailResult> {
  const env = readAuthEmailEnvStatus();
  const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
  const from = process.env.EMAIL_FROM?.trim() ?? "";

  const base: SendAuthCodeEmailResult = {
    resendInitialized: false,
    emailFromPresent: env.emailFromConfigured,
    apiKeyPresent: env.resendConfigured,
    resendResponseId: null,
    resendErrorName: null,
    resendErrorMessage: null,
  };

  if (!isProduction()) {
    return base;
  }

  if (!apiKey) {
    throw new AuthEmailError(
      "AUTH_RESEND_NOT_CONFIGURED",
      "RESEND_API_KEY is not configured.",
    );
  }
  if (!from) {
    throw new AuthEmailError(
      "AUTH_RESEND_NOT_CONFIGURED",
      "EMAIL_FROM is not configured.",
    );
  }
  if (!env.emailFromFormatValid) {
    throw new AuthEmailError(
      "AUTH_INVALID_EMAIL_FROM",
      "EMAIL_FROM format is invalid.",
    );
  }

  const resend = new Resend(apiKey);
  base.resendInitialized = true;

  const { data, error } = await resend.emails.send({
    from,
    to: [email],
    subject: SUBJECT,
    text: buildEmailBody(code),
  });

  if (error) {
    const message = error.message ?? "Resend rejected the send request.";
    base.resendErrorName = error.name ?? "resend_error";
    base.resendErrorMessage = message;

    const code: AuthErrorCode = isSenderRejection(message)
      ? "AUTH_RESEND_REJECTED"
      : "AUTH_EMAIL_SEND_FAILED";

    throw new AuthEmailError(code, message);
  }

  if (!data?.id) {
    base.resendErrorMessage = "Resend response missing email id.";
    throw new AuthEmailError(
      "AUTH_EMAIL_SEND_FAILED",
      "Resend did not return a delivery id.",
    );
  }

  base.resendResponseId = data.id;
  return base;
}
