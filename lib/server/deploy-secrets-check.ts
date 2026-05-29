import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import { getEmailMode, isEmailDisabled } from "@/lib/server/email-mode";
import { verifyMigrations } from "@/lib/server/migration-verify";
import {
  isAuthSecretStrong,
  isDebugTokenStrong,
} from "@/lib/server/production-env";
import { usesDurableRateLimits } from "@/lib/server/api-usage-store";
import { dbQuery, hasDatabaseUrl } from "@/lib/server/db";

export type DeployCheckStatus = "pass" | "fail" | "skip";

export interface DeployCheckResult {
  name: string;
  status: DeployCheckStatus;
  detail: string;
}

export interface DeploySecretsReport {
  ok: boolean;
  checks: DeployCheckResult[];
  liveStripeProofRequired: boolean;
}

function httpsAppUrl(): string | null {
  return (
    process.env.NEXT_PUBLIC_APP_URL?.trim() ||
    process.env.APP_URL?.trim() ||
    null
  );
}

export async function validateDeploySecrets(): Promise<DeploySecretsReport> {
  const checks: DeployCheckResult[] = [];

  const add = (name: string, status: DeployCheckStatus, detail: string) => {
    checks.push({ name, status, detail });
  };

  if (!hasDatabaseUrl()) {
    add("DATABASE_URL", "skip", "Not set — cannot verify connectivity.");
  } else {
    try {
      await dbQuery("SELECT 1");
      add("DATABASE_URL", "pass", "Connection OK.");
      const migrations = await verifyMigrations();
      add(
        "migrations",
        migrations.ok ? "pass" : "fail",
        migrations.ok
          ? "Required tables/indexes present."
          : `Missing: tables=${migrations.missingTables.join(",")} indexes=${migrations.missingIndexes.join(",")}`,
      );
    } catch (error) {
      add(
        "DATABASE_URL",
        "fail",
        error instanceof Error ? error.message : "Connection failed",
      );
    }
  }

  add(
    "AUTH_SECRET",
    isAuthSecretStrong(process.env.AUTH_SECRET) ? "pass" : "fail",
    isAuthSecretStrong(process.env.AUTH_SECRET)
      ? "Strong secret present."
      : "Missing or weak AUTH_SECRET.",
  );

  add(
    "OPENAI_API_KEY",
    process.env.OPENAI_API_KEY?.trim() ? "pass" : "fail",
    process.env.OPENAI_API_KEY?.trim() ? "Present." : "Missing.",
  );

  const appUrl = httpsAppUrl();
  if (!appUrl) {
    add("APP_URL", "fail", "NEXT_PUBLIC_APP_URL or APP_URL missing.");
  } else if (process.env.NODE_ENV === "production" && !appUrl.startsWith("https://")) {
    add("APP_URL", "fail", "Production app URL must be HTTPS.");
  } else {
    add("APP_URL", "pass", "App URL configured.");
  }

  const stripe = getStripeBillingConfig();
  if (!stripe.enabled) {
    add("STRIPE", "skip", "Stripe env incomplete — live Stripe proof blocked.");
  } else {
    const key = process.env.STRIPE_SECRET_KEY ?? "";
    const liveMode = key.startsWith("sk_live_");
    const testMode = key.startsWith("sk_test_");
    add(
      "STRIPE_SECRET_KEY",
      liveMode || (process.env.NODE_ENV !== "production" && testMode)
        ? "pass"
        : "fail",
      liveMode
        ? "Live-mode key detected (prefix only)."
        : testMode
          ? "Test key (OK for non-production)."
          : "Unrecognized key prefix.",
    );

    add(
      "STRIPE_WEBHOOK_SECRET",
      process.env.STRIPE_WEBHOOK_SECRET?.trim() ? "pass" : "fail",
      "Webhook secret present (value not logged).",
    );

    if (stripe.secretKey && stripe.priceId) {
      try {
        const { default: Stripe } = await import("stripe");
        const client = new Stripe(stripe.secretKey);
        await client.prices.retrieve(stripe.priceId);
        add("STRIPE_PRO_PRICE_ID", "pass", "Price lookup succeeded.");
      } catch (error) {
        add(
          "STRIPE_PRO_PRICE_ID",
          "fail",
          error instanceof Error ? error.message : "Price lookup failed",
        );
      }
    } else {
      add("STRIPE_PRO_PRICE_ID", "fail", "Stripe secret or price id unavailable.");
    }
  }

  if (isEmailDisabled()) {
    add("EMAIL", "pass", "EMAIL_DISABLED=true — Resend not required.");
  } else {
    const mode = getEmailMode();
    add(
      "EMAIL",
      mode === "resend" ? "pass" : "fail",
      mode === "resend" ? "Resend configured." : "RESEND_API_KEY + EMAIL_FROM required.",
    );
  }

  const debugToken = process.env.DEBUG_ACCESS_TOKEN?.trim();
  if (!debugToken) {
    add("DEBUG_ACCESS_TOKEN", "pass", "Unset — debug/demo return 404 (recommended).");
  } else {
    add(
      "DEBUG_ACCESS_TOKEN",
      isDebugTokenStrong(debugToken) ? "pass" : "fail",
      isDebugTokenStrong(debugToken)
        ? "Strong token (value not logged)."
        : "Weak or guessable DEBUG_ACCESS_TOKEN.",
    );
  }

  add(
    "RATE_LIMITER_DURABLE",
    usesDurableRateLimits() ? "pass" : "fail",
    usesDurableRateLimits()
      ? "Postgres-backed rate limits active."
      : "Memory-only limits — not A+ in production.",
  );

  const failed = checks.some((c) => c.status === "fail");
  const liveStripeProofRequired = !isStripeConfigured();

  return {
    ok: !failed,
    checks,
    liveStripeProofRequired,
  };
}
