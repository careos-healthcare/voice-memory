import { isStripeConfigured } from "@/lib/billing/stripe-config";
import { usesDurableRateLimits } from "@/lib/server/api-usage-store";
import { assertProductionOpenAiSpendIsDurable } from "@/lib/server/openai-spend-store";
import { hasDatabaseUrl } from "@/lib/server/db";
import { getEmailMode } from "@/lib/server/email-mode";
import {
  formatProductionEnvReport,
  validateProductionEnv,
} from "@/lib/server/production-env";

export interface ProductionReadinessSnapshot {
  databaseUrl: boolean;
  rateLimiterDurable: boolean;
  stripeConfigured: boolean;
  emailMode: ReturnType<typeof getEmailMode>;
  envOk: boolean;
}

export function getProductionReadinessSnapshot(): ProductionReadinessSnapshot {
  const env = validateProductionEnv({ strict: true });
  return {
    databaseUrl: hasDatabaseUrl(),
    rateLimiterDurable: usesDurableRateLimits(),
    stripeConfigured: isStripeConfigured(),
    emailMode: getEmailMode(),
    envOk: env.ok,
  };
}

/** Throws in production runtime when Grade A infra is not active. */
export function assertProductionRuntimeReadiness(): void {
  if (process.env.NODE_ENV !== "production") return;
  if (process.env.NEXT_PHASE === "phase-production-build") return;
  /** Playwright UI smoke only — does not relax deploy validators. */
  if (process.env.VOICEMEMORY_UI_E2E === "1") return;

  const env = validateProductionEnv({ strict: true });
  if (!env.ok) {
    throw new Error(
      `Production readiness failed:\n${formatProductionEnvReport(env)}`,
    );
  }

  if (!usesDurableRateLimits()) {
    throw new Error(
      "Production requires DATABASE_URL for DB-backed global rate limits (not memory-only).",
    );
  }

  assertProductionOpenAiSpendIsDurable();
}
