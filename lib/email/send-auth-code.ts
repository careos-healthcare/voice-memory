import "server-only";

const SUBJECT = "Your VoiceMemory sign-in code";

export class AuthEmailNotConfiguredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthEmailNotConfiguredError";
  }
}

export class AuthEmailDeliveryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthEmailDeliveryError";
  }
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

interface ResendEmailResponse {
  id?: string;
  name?: string;
  message?: string;
}

/** Send the sign-in code through Resend in production. */
export async function sendAuthCodeEmail(email: string, code: string): Promise<void> {
  if (!isProduction()) return;

  const apiKey = process.env.RESEND_API_KEY?.trim();
  const from = process.env.EMAIL_FROM?.trim();

  if (!apiKey) {
    throw new AuthEmailNotConfiguredError("RESEND_API_KEY is not configured.");
  }
  if (!from) {
    throw new AuthEmailNotConfiguredError("EMAIL_FROM is not configured.");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: SUBJECT,
      text: buildEmailBody(code),
    }),
  });

  let payload: ResendEmailResponse | null = null;
  try {
    payload = (await response.json()) as ResendEmailResponse;
  } catch {
    payload = null;
  }

  if (!response.ok) {
    console.error("[VoiceMemory auth] Resend delivery failed", {
      status: response.status,
      name: payload?.name ?? null,
      message: payload?.message ?? null,
    });
    throw new AuthEmailDeliveryError("Could not send the email. Try again in a moment.");
  }

  if (!payload?.id) {
    console.error("[VoiceMemory auth] Resend response missing id", {
      status: response.status,
      name: payload?.name ?? null,
      message: payload?.message ?? null,
    });
    throw new AuthEmailDeliveryError("Could not send the email. Try again in a moment.");
  }
}
