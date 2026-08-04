/**
 * Production environment validation — fail closed in production, warn in development.
 */

import { isStripeConfigured } from "@/lib/billing/stripe-config";
import { isEmailDisabled } from "@/lib/server/email-mode";
import {
  isUnitEconomicsEnabled,
  validateUnitEconomicsConfiguration,
} from "@/lib/server/unit-economics-config";
import { validateProductionUsageAllowances } from "@/lib/server/usage-allowance-config";

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

  if (isUnitEconomicsEnabled()) {
    for (const message of validateUnitEconomicsConfiguration()) {
      push("error", "UNIT_ECONOMICS", message);
    }
  }

  for (const message of validateProductionUsageAllowances()) {
    push("error", "USAGE_ALLOWANCES", message);
  }

  for (const name of [
    "VOICEMEMORY_DAILY_TRANSCRIBE_LIMIT",
    "VOICEMEMORY_MINUTE_TRANSCRIBE_LIMIT",
    "VOICEMEMORY_DAILY_ANALYZE_LIMIT",
    "VOICEMEMORY_MINUTE_ANALYZE_LIMIT",
    "VOICEMEMORY_DAILY_ATMOSPHERE_LIMIT",
    "VOICEMEMORY_MINUTE_ATMOSPHERE_LIMIT",
    "VOICEMEMORY_DAILY_ATTEST_LIMIT",
    "VOICEMEMORY_MINUTE_ATTEST_LIMIT",
    "VOICEMEMORY_DAILY_LIVE_AUDIO_LIMIT",
    "VOICEMEMORY_MINUTE_LIVE_AUDIO_LIMIT",
  ]) {
    const value = Number(process.env[name]);
    if (!Number.isSafeInteger(value) || value <= 0) {
      push(
        "error",
        "USAGE_RATE_LIMITS",
        `${name} must be a positive integer; production has no default.`,
      );
    }
  }

  if (!process.env.REVENUECAT_SECRET_API_KEY?.trim()) {
    push(
      "error",
      "REVENUECAT_SECRET_API_KEY",
      "REVENUECAT_SECRET_API_KEY is required for server entitlement verification.",
    );
  }
  if ((process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN?.trim().length ?? 0) < 32) {
    push(
      "error",
      "REVENUECAT_WEBHOOK_AUTH_TOKEN",
      "REVENUECAT_WEBHOOK_AUTH_TOKEN must be at least 32 characters.",
    );
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
