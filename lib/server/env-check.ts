import "server-only";

const EMAIL_FROM_RE = /^.+<[^@\s]+@[^>\s]+>$/;
const PLAIN_EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export interface AuthEmailEnvStatus {
  resendConfigured: boolean;
  emailFromConfigured: boolean;
  emailFromFormatValid: boolean;
  appUrlConfigured: boolean;
}

export function readAuthEmailEnvStatus(): AuthEmailEnvStatus {
  const from = process.env.EMAIL_FROM?.trim() ?? "";
  const emailFromFormatValid =
    Boolean(from) &&
    (EMAIL_FROM_RE.test(from) || PLAIN_EMAIL_RE.test(from) || from.includes("@"));

  return {
    resendConfigured: Boolean(process.env.RESEND_API_KEY?.trim()),
    emailFromConfigured: Boolean(from),
    emailFromFormatValid,
    appUrlConfigured: Boolean(process.env.NEXT_PUBLIC_APP_URL?.trim()),
  };
}

/** Called at server startup in production — fails fast when email auth cannot work. */
export function validateProductionAuthEmailEnv(): void {
  if (process.env.NODE_ENV !== "production") return;
  if (process.env.NEXT_PHASE === "phase-production-build") return;

  const status = readAuthEmailEnvStatus();
  const missing: string[] = [];
  if (!status.resendConfigured) missing.push("RESEND_API_KEY");
  if (!status.emailFromConfigured) missing.push("EMAIL_FROM");

  if (missing.length > 0) {
    throw new Error(
      `Production auth email misconfigured. Set: ${missing.join(", ")}. Sign-in codes cannot be delivered.`,
    );
  }
}

export function assertEmailFromConfigured(): void {
  const from = process.env.EMAIL_FROM?.trim();
  if (!from) {
    throw new Error("EMAIL_FROM is not configured.");
  }
}
