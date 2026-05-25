import type { AuthErrorCode } from "@/types/auth-errors";

const AUTH_CODE_MESSAGES: Record<AuthErrorCode, string> = {
  AUTH_EMAIL_SEND_FAILED: "Email delivery is temporarily unavailable.",
  AUTH_INVALID_EMAIL_FROM: "Auth email provider rejected the sender address.",
  AUTH_RESEND_NOT_CONFIGURED: "Email delivery is temporarily unavailable.",
  AUTH_RESEND_REJECTED: "Auth email provider rejected the sender address.",
  AUTH_STORAGE_NOT_CONFIGURED: "Auth storage is not configured.",
  AUTH_EMAIL_REQUIRED: "Email is required.",
  AUTH_INVALID_REQUEST: "Email delivery is temporarily unavailable.",
};

export function mapAuthErrorToUserMessage(code: string | undefined, fallback?: string): string {
  if (code && code in AUTH_CODE_MESSAGES) {
    return AUTH_CODE_MESSAGES[code as AuthErrorCode];
  }

  if (fallback && !/try again/i.test(fallback)) {
    return fallback;
  }

  return "Email delivery is temporarily unavailable.";
}
