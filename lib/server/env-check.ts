import "server-only";

const EMAIL_FROM_RE = /^.+<[^@\s]+@[^>\s]+>$/;
const PLAIN_EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const RESEND_SANDBOX_FROM = /onboarding@resend\.dev/i;

export interface AuthEmailEnvStatus {
  resendConfigured: boolean;
  emailFromConfigured: boolean;
  emailFromFormatValid: boolean;
  /** True when EMAIL_FROM still uses Resend's sandbox sender (not production-ready). */
  emailFromUsesResendSandbox: boolean;
  /** Domain part of the From address, for ops checks (no local-part). */
  emailFromDomain: string | null;
  appUrlConfigured: boolean;
}

function parseEmailFromDomain(from: string): string | null {
  const trimmed = from.trim();
  const bracket = trimmed.match(/<([^>]+)>/);
  const addr = (bracket?.[1] ?? trimmed).trim();
  const at = addr.lastIndexOf("@");
  if (at < 1 || at >= addr.length - 1) return null;
  return addr.slice(at + 1).toLowerCase();
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
    emailFromUsesResendSandbox: RESEND_SANDBOX_FROM.test(from),
    emailFromDomain: from ? parseEmailFromDomain(from) : null,
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
