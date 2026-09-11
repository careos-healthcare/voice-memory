import "server-only";

import { Resend } from "resend";

import { readAuthEmailEnvStatus } from "@/lib/server/env-check";

const SUBJECT = "You're invited to ArchiveMe as a caregiver";

export type CaregiverInviteEmailErrorCode =
  | "CAREGIVER_INVITE_RESEND_NOT_CONFIGURED"
  | "CAREGIVER_INVITE_INVALID_EMAIL_FROM"
  | "CAREGIVER_INVITE_RESEND_REJECTED"
  | "CAREGIVER_INVITE_EMAIL_SEND_FAILED";

export class CaregiverInviteEmailError extends Error {
  code: CaregiverInviteEmailErrorCode;

  constructor(code: CaregiverInviteEmailErrorCode, message: string) {
    super(message);
    this.name = "CaregiverInviteEmailError";
    this.code = code;
  }
}

export interface SendCaregiverInviteEmailResult {
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

function buildInviteUrl(linkToken: string): string {
  return `https://archiveme.app/caregiver/invite?token=${linkToken}`;
}

function buildEmailBody(params: {
  linkToken: string;
  reference: string;
  manualCode: string;
}): string {
  const inviteUrl = buildInviteUrl(params.linkToken);
  return `Someone invited you to view their ArchiveMe archive as a caregiver.

Open this link on your phone:

${inviteUrl}

If the link does not open, enter reference ${params.reference} and code ${params.manualCode}.`;
}

function isSenderRejection(message: string): boolean {
  return /from|sender|domain|not verified|invalid.*address/i.test(message);
}

/** Send the caregiver invite through Resend in production. */
export async function sendCaregiverInviteEmail(
  email: string,
  params: { linkToken: string; reference: string; manualCode: string },
): Promise<SendCaregiverInviteEmailResult> {
  const env = readAuthEmailEnvStatus();
  const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
  const from = process.env.EMAIL_FROM?.trim() ?? "";

  const base: SendCaregiverInviteEmailResult = {
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
    throw new CaregiverInviteEmailError(
      "CAREGIVER_INVITE_RESEND_NOT_CONFIGURED",
      "RESEND_API_KEY is not configured.",
    );
  }
  if (!from) {
    throw new CaregiverInviteEmailError(
      "CAREGIVER_INVITE_RESEND_NOT_CONFIGURED",
      "EMAIL_FROM is not configured.",
    );
  }
  if (!env.emailFromFormatValid) {
    throw new CaregiverInviteEmailError(
      "CAREGIVER_INVITE_INVALID_EMAIL_FROM",
      "EMAIL_FROM format is invalid.",
    );
  }

  const resend = new Resend(apiKey);
  base.resendInitialized = true;

  const { data, error } = await resend.emails.send({
    from,
    to: [email],
    subject: SUBJECT,
    text: buildEmailBody(params),
  });

  if (error) {
    const message = error.message ?? "Resend rejected the send request.";
    base.resendErrorName = error.name ?? "resend_error";
    base.resendErrorMessage = message;

    const code: CaregiverInviteEmailErrorCode = isSenderRejection(message)
      ? "CAREGIVER_INVITE_RESEND_REJECTED"
      : "CAREGIVER_INVITE_EMAIL_SEND_FAILED";

    throw new CaregiverInviteEmailError(code, message);
  }

  if (!data?.id) {
    base.resendErrorMessage = "Resend response missing email id.";
    throw new CaregiverInviteEmailError(
      "CAREGIVER_INVITE_EMAIL_SEND_FAILED",
      "Resend did not return a delivery id.",
    );
  }

  base.resendResponseId = data.id;
  return base;
}
