/**
 * Production environment validation — fail closed in production, warn in development.
 */

import { isStripeConfigured } from "@/lib/billing/stripe-config";
import { isEmailDisabled } from "@/lib/server/email-mode";

const WEAK_DEBUG_TOKENS = new Set([
  "debug",
  "test",
  "changeme",
  "password",
  "secret",
  "vm_debug",
  "debug_token",
  "founder",
]);

const WEAK_AUTH_SECRETS = [
  "dev-only-auth-secret-change-me",
  "dev-only-auth-secret",
  "change-me",
  "changeme",
  "test-secret",
];

export interface ProductionEnvIssue {
  level: "error" | "warning";
  code: string;
  message: string;
}

export interface ProductionEnvReport {
  ok: boolean;
  strict: boolean;
  issues: ProductionEnvIssue[];
}

function isProductionMode(strict: boolean): boolean {
  return strict || process.env.NODE_ENV === "production";
}

function appUrlPresent(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_APP_URL?.trim() || process.env.APP_URL?.trim(),
  );
}

export function isDebugTokenStrong(token: string | undefined): boolean {
  const t = token?.trim() ?? "";
  if (t.length < 24) return false;
  if (WEAK_DEBUG_TOKENS.has(t.toLowerCase())) return false;
  if (/^(.)\1{5,}/.test(t)) return false;
  return true;
}

export function isAuthSecretStrong(secret: string | undefined): boolean {
  const s = secret?.trim() ?? "";
  if (s.length < 32) return false;
  const lower = s.toLowerCase();
  if (WEAK_AUTH_SECRETS.some((w) => lower.includes(w))) return false;
  return true;
}

/** Validate env for Grade A production deploy. */
export function validateProductionEnv(options?: {
  strict?: boolean;
}): ProductionEnvReport {
  const strict = options?.strict ?? isProductionMode(false);
  const issues: ProductionEnvIssue[] = [];

  const push = (level: ProductionEnvIssue["level"], code: string, message: string) => {
    issues.push({ level, code, message });
  };

  if (!process.env.DATABASE_URL?.trim()) {
    push("error", "DATABASE_URL", "DATABASE_URL is required for durable auth, limits, and journal.");
  }

  if (!isAuthSecretStrong(process.env.AUTH_SECRET)) {
    push(
      "error",
      "AUTH_SECRET",
      "AUTH_SECRET must be at least 32 characters and not a dev/default value.",
    );
  }

  if (!process.env.OPENAI_API_KEY?.trim()) {
    push("error", "OPENAI_API_KEY", "OPENAI_API_KEY is required for voice analysis.");
  }

  if (!appUrlPresent()) {
    push("error", "APP_URL", "Set NEXT_PUBLIC_APP_URL or APP_URL for checkout redirects and links.");
  }

  if (!isStripeConfigured()) {
    push(
      "error",
      "STRIPE",
      "Stripe is not fully configured (STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRO_PRICE_ID, app URL).",
    );
  }

  if (!isEmailDisabled()) {
    if (!process.env.RESEND_API_KEY?.trim()) {
      push(
        "error",
        "RESEND_API_KEY",
        "RESEND_API_KEY is required unless EMAIL_DISABLED=true.",
      );
    }
    if (!process.env.EMAIL_FROM?.trim()) {
      push("error", "EMAIL_FROM", "EMAIL_FROM is required when email is enabled.");
    }
  }

  const debugToken = process.env.DEBUG_ACCESS_TOKEN?.trim();
  if (!debugToken) {
    push(
      "warning",
      "DEBUG_ACCESS_TOKEN",
      "DEBUG_ACCESS_TOKEN unset — /internal and /demo return 404 in production (recommended).",
    );
  } else if (!isDebugTokenStrong(debugToken)) {
    push(
      "error",
      "DEBUG_ACCESS_TOKEN",
      "DEBUG_ACCESS_TOKEN must be at least 24 chars and not a default/guessable value.",
    );
  }

  if (strict && !process.env.DATABASE_URL?.trim()) {
    // rate limiter + journal grade A dependency
  }

  const errors = issues.filter((i) => i.level === "error");
  const ok = errors.length === 0;

  return { ok, strict, issues };
}

export function formatProductionEnvReport(report: ProductionEnvReport): string {
  return report.issues
    .map((i) => `[${i.level}] ${i.code}: ${i.message}`)
    .join("\n");
}
