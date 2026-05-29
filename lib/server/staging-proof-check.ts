/**
 * Staging/production proof — never logs secret values.
 * Run only when VOICEMEMORY_STAGING_PROOF=1 (or --require).
 */

import { writeFileSync } from "node:fs";

import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import { getEmailMode, isEmailDisabled } from "@/lib/server/email-mode";
import { verifyMigrations } from "@/lib/server/migration-verify";
import { usesDurableRateLimits } from "@/lib/server/api-usage-store";
import { dbQuery, hasDatabaseUrl } from "@/lib/server/db";
import {
  BILLING_STATUS_PATH,
  EMAIL_STATUS_PATH,
  isFreshIsoDate,
  readJsonFile,
  requireTruthy,
  STAGING_STATUS_PATH,
} from "@/lib/proof/signoff-files";

export type StagingCheckStatus = "pass" | "fail" | "skip" | "manual";

export interface StagingCheckResult {
  name: string;
  status: StagingCheckStatus;
  detail: string;
}

export interface StagingProofReport {
  ok: boolean;
  blocked: boolean;
  checks: StagingCheckResult[];
  wroteStatus?: boolean;
}

function appUrl(): string | null {
  return (
    process.env.NEXT_PUBLIC_APP_URL?.trim() ||
    process.env.APP_URL?.trim() ||
    null
  );
}

async function fetchHealth(baseUrl: string): Promise<{
  ok: boolean;
  detail: string;
  body?: Record<string, unknown>;
}> {
  try {
    const res = await fetch(new URL("/api/health", baseUrl).toString(), {
      signal: AbortSignal.timeout(12_000),
    });
    const body = (await res.json()) as Record<string, unknown>;
    const checks = body.checks as Record<string, unknown> | undefined;
    const leaked = JSON.stringify(body).match(/sk_live|sk_test|whsec_|DEBUG_ACCESS_TOKEN/i);
    if (leaked) {
      return { ok: false, detail: "Health JSON leaked secret-like patterns." };
    }
    if (!res.ok) {
      return { ok: false, detail: `HTTP ${res.status}`, body };
    }
    const migrationsOk = checks?.migrationsOk === true;
    const rateMode = checks?.rateLimiterMode;
    return {
      ok: migrationsOk && (rateMode === "postgres" || rateMode === "durable"),
      detail: `migrationsOk=${String(checks?.migrationsOk)} rateLimiterMode=${String(rateMode)}`,
      body,
    };
  } catch (error) {
    return {
      ok: false,
      detail: error instanceof Error ? error.message : "Health fetch failed",
    };
  }
}

export async function validateStagingProof(options?: {
  require?: boolean;
}): Promise<StagingProofReport> {
  const require =
    options?.require ??
    (process.env.VOICEMEMORY_STAGING_PROOF === "1" ||
      process.argv.includes("--require"));

  const checks: StagingCheckResult[] = [];
  const add = (name: string, status: StagingCheckStatus, detail: string) => {
    checks.push({ name, status, detail });
  };

  if (!require) {
    add(
      "STAGING_PROOF_MODE",
      "skip",
      "Set VOICEMEMORY_STAGING_PROOF=1 against staging deploy to run live checks.",
    );
    return { ok: true, blocked: true, checks };
  }

  if (!hasDatabaseUrl()) {
    add("DATABASE_URL", "fail", "Missing — cannot verify DB or durable rate limits.");
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
          : `Missing tables/indexes.`,
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
    "RATE_LIMITER_DURABLE",
    usesDurableRateLimits() ? "pass" : "fail",
    usesDurableRateLimits()
      ? "Postgres-backed rate limits active."
      : "Memory-only — not acceptable on staging/prod.",
  );

  const stripe = getStripeBillingConfig();
  if (!isStripeConfigured()) {
    add("STRIPE_ENV", "fail", "Stripe env incomplete on this host.");
  } else {
    add("STRIPE_ENV", "pass", "Stripe secret + price + webhook env present (values not logged).");
    if (stripe.secretKey && stripe.priceId) {
      try {
        const { default: Stripe } = await import("stripe");
        const client = new Stripe(stripe.secretKey);
        await client.prices.retrieve(stripe.priceId);
        add("STRIPE_PRICE_LOOKUP", "pass", "Price retrieve succeeded.");
      } catch (error) {
        add(
          "STRIPE_PRICE_LOOKUP",
          "fail",
          error instanceof Error ? error.message : "Price lookup failed",
        );
      }
    }
  }

  const billingStatus = readJsonFile(BILLING_STATUS_PATH);
  const webhookFileOk =
    isFreshIsoDate(billingStatus?.verifiedAt) &&
    billingStatus?.stripeWebhookVerified === true;
  const webhookEnv = process.env.VOICEMEMORY_STRIPE_WEBHOOK_PROOF === "1";
  const webhookOk = webhookFileOk || webhookEnv;
  add(
    "STRIPE_WEBHOOK_MANUAL_PROOF",
    isStripeConfigured() ? (webhookOk ? "pass" : "manual") : "skip",
    webhookOk
      ? "Webhook proof attested (status file or VOICEMEMORY_STRIPE_WEBHOOK_PROOF=1)."
      : "Complete Stripe test webhook; update live_billing_proof_status.json or set env flag.",
  );

  if (isEmailDisabled()) {
    add("RESEND", "pass", "EMAIL_DISABLED=true — Resend not required.");
  } else {
    const emailModeOk = getEmailMode() === "resend";
    const emailStatus = readJsonFile(EMAIL_STATUS_PATH);
    const deliveryFileOk =
      isFreshIsoDate(emailStatus?.verifiedAt) && emailStatus?.deliveryVerified === true;
    add(
      "RESEND",
      emailModeOk && deliveryFileOk ? "pass" : emailModeOk ? "manual" : "fail",
      emailModeOk
        ? deliveryFileOk
          ? "Resend configured and delivery proof file fresh."
          : "Resend configured — set email_delivery_proof_status.json after inbox test."
        : "RESEND_API_KEY + EMAIL_FROM required when email enabled.",
    );
  }

  const url = appUrl();
  if (!url) {
    add("APP_URL", "fail", "NEXT_PUBLIC_APP_URL or APP_URL missing.");
  } else if (!url.startsWith("https://")) {
    add("APP_URL", "fail", "Staging app URL must be HTTPS.");
  } else {
    add("APP_URL", "pass", "HTTPS app URL configured (host not logged).");
    const health = await fetchHealth(url);
    add(
      "HEALTH_ENDPOINT",
      health.ok ? "pass" : "fail",
      health.detail,
    );
  }

  const failed = checks.some((c) => c.status === "fail");
  const manualPending = checks.some((c) => c.status === "manual");
  const liveOk = !failed && !manualPending;

  let wroteStatus = false;
  if (liveOk && process.env.VOICEMEMORY_WRITE_STAGING_STATUS === "1") {
    const status = {
      version: 1,
      verifiedAt: new Date().toISOString(),
      verifiedBy: process.env.VOICEMEMORY_PROOF_VERIFIED_BY ?? "staging-validator",
      databaseReachable: checks.find((c) => c.name === "DATABASE_URL")?.status === "pass",
      migrationsOk: checks.find((c) => c.name === "migrations")?.status === "pass",
      rateLimiterDurable:
        checks.find((c) => c.name === "RATE_LIMITER_DURABLE")?.status === "pass",
      stripePriceLookup:
        checks.find((c) => c.name === "STRIPE_PRICE_LOOKUP")?.status === "pass",
      httpsAppUrl: checks.find((c) => c.name === "APP_URL")?.status === "pass",
      healthOk: checks.find((c) => c.name === "HEALTH_ENDPOINT")?.status === "pass",
      notes: "Written by validate:staging-proof after live checks passed.",
    };
    writeFileSync(STAGING_STATUS_PATH, JSON.stringify(status, null, 2) + "\n");
    wroteStatus = true;
  }

  const requireStatusFile =
    process.env.VOICEMEMORY_REQUIRE_STAGING_STATUS_FILE === "1" ||
    process.env.VOICEMEMORY_STAGING_PROOF === "1";

  if (liveOk && requireStatusFile) {
    const file = readJsonFile(STAGING_STATUS_PATH);
    const missing = requireTruthy(file, [
      "databaseReachable",
      "migrationsOk",
      "rateLimiterDurable",
      "stripePriceLookup",
      "httpsAppUrl",
      "healthOk",
    ]);
    if (!isFreshIsoDate(file?.verifiedAt)) {
      missing.push("verifiedAt missing or stale (>30d)");
    }
    if (missing.length) {
      for (const m of missing) {
        add("STAGING_STATUS_FILE", "fail", m);
      }
    } else {
      add("STAGING_STATUS_FILE", "pass", "Fresh staging_proof_status.json present.");
    }
  }

  const failedAfter = checks.some((c) => c.status === "fail");
  const manualAfter = checks.some((c) => c.status === "manual");

  return {
    ok: !failedAfter && !manualAfter,
    blocked: false,
    checks,
    wroteStatus,
  };
}
