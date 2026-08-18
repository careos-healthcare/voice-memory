import { NextResponse } from "next/server";

import { isStripeConfigured } from "@/lib/billing/stripe-config";
import { isRedisRateLimitConfigured } from "@/lib/rate-limit/enforce";
import { usesDurableRateLimits } from "@/lib/server/api-usage-store";
import { hasDatabaseUrl } from "@/lib/server/db";
import { getEmailMode } from "@/lib/server/email-mode";
import { verifyMigrations } from "@/lib/server/migration-verify";
import { getProductionReadinessSnapshot } from "@/lib/server/production-readiness";
import { logServerEvent } from "@/lib/server/structured-log";

export const runtime = "nodejs";

/** Deep readiness — checks DB migrations and billing config. Use `/api/healthz` for liveness. */
export async function GET() {
  const snapshot = getProductionReadinessSnapshot();
  let databaseReachable = false;
  let migrationsOk = false;

  if (hasDatabaseUrl()) {
    try {
      const migration = await verifyMigrations();
      databaseReachable = !migration.skipped && migration.errors.length === 0;
      migrationsOk = migration.ok;
    } catch {
      databaseReachable = false;
    }
  }

  const healthy =
    databaseReachable &&
    migrationsOk &&
    (!process.env.NODE_ENV ||
      process.env.NODE_ENV !== "production" ||
      (snapshot.rateLimiterDurable && snapshot.stripeConfigured));

  logServerEvent("health_check", {
    healthy,
    databaseReachable,
    migrationsOk,
    rateLimiterDurable: usesDurableRateLimits(),
  });

  return NextResponse.json({
    status: healthy ? "ok" : "degraded",
    checks: {
      databaseConfigured: hasDatabaseUrl(),
      databaseReachable,
      migrationsOk,
      rateLimiterMode: usesDurableRateLimits() ? "postgres" : "memory",
      globalRateLimiterMode: isRedisRateLimitConfigured() ? "redis" : "disabled",
      stripeConfigured: isStripeConfigured(),
      emailMode: getEmailMode(),
      productionEnvOk: snapshot.envOk,
    },
  });
}
