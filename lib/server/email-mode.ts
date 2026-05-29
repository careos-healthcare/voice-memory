/**
 * Email delivery mode — Resend required in production unless explicitly disabled.
 */

export function isEmailDisabled(): boolean {
  return process.env.EMAIL_DISABLED === "true";
}

export function isEmailRequiredInProduction(): boolean {
  return process.env.NODE_ENV === "production" && !isEmailDisabled();
}

export function getEmailMode(): "resend" | "disabled" | "unconfigured" {
  if (isEmailDisabled()) return "disabled";
  if (process.env.RESEND_API_KEY?.trim() && process.env.EMAIL_FROM?.trim()) {
    return "resend";
  }
  return "unconfigured";
}
