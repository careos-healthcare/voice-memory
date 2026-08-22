import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import {
  rememberWebhookEventCreatedAt,
  shouldApplyBillingWebhookUpdate,
} from "@/lib/server/billing-webhook-ordering";
import { resolveRevenueCatSubscriberEntitlements } from "@/lib/server/revenuecat-rest";
import type { EntitlementId } from "@/types/entitlement";
import { entitlementsForTier } from "@/lib/entitlement/tiers";

export type BillingSubscriptionStatus =
  | "active"
  | "trialing"
  | "past_due"
  | "canceled"
  | "unpaid"
  | "incomplete";

export interface ServerBillingRecord {
  userId: string;
  stripeCustomerId: string | null;
  stripeSubscriptionId: string | null;
  status: BillingSubscriptionStatus;
  tier: "free" | "pro";
  updatedAt: string;
}

const memoryBilling = globalThis as typeof globalThis & {
  __vmBilling?: Map<string, ServerBillingRecord>;
};

function memoryMap(): Map<string, ServerBillingRecord> {
  if (!memoryBilling.__vmBilling) memoryBilling.__vmBilling = new Map();
  return memoryBilling.__vmBilling;
}

function isPaidStatus(status: BillingSubscriptionStatus): boolean {
  return status === "active" || status === "trialing";
}

export async function getServerBillingRecord(
  userId: string,
): Promise<ServerBillingRecord | null> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      user_id: string;
      stripe_customer_id: string | null;
      stripe_subscription_id: string | null;
      status: BillingSubscriptionStatus;
      tier: "free" | "pro";
      updated_at: Date;
    }>(
      `SELECT user_id, stripe_customer_id, stripe_subscription_id, status, tier, updated_at
       FROM billing_entitlements WHERE user_id = $1`,
      [userId],
    );
    const row = result.rows[0];
    if (!row) return null;
    return {
      userId: row.user_id,
      stripeCustomerId: row.stripe_customer_id,
      stripeSubscriptionId: row.stripe_subscription_id,
      status: row.status,
      tier: row.tier,
      updatedAt: row.updated_at.toISOString(),
    };
  }
  return memoryMap().get(userId) ?? null;
}

export async function upsertServerBillingRecord(input: {
  userId: string;
  stripeCustomerId?: string | null;
  stripeSubscriptionId?: string | null;
  status: BillingSubscriptionStatus;
  tier?: "free" | "pro";
  eventCreatedAt?: number;
}): Promise<ServerBillingRecord> {
  if (input.eventCreatedAt != null) {
    const existing = await getServerBillingRecord(input.userId);
    const decision = shouldApplyBillingWebhookUpdate({
      userId: input.userId,
      incomingStatus: input.status,
      existingStatus: existing?.status ?? null,
      eventCreatedAt: input.eventCreatedAt,
    });
    if (!decision.apply) {
      if (existing) return existing;
      return {
        userId: input.userId,
        stripeCustomerId: input.stripeCustomerId ?? null,
        stripeSubscriptionId: input.stripeSubscriptionId ?? null,
        status: input.status,
        tier: input.tier ?? (isPaidStatus(input.status) ? "pro" : "free"),
        updatedAt: new Date().toISOString(),
      };
    }
    rememberWebhookEventCreatedAt(input.userId, input.eventCreatedAt);
  }

  const tier =
    input.tier ?? (isPaidStatus(input.status) ? "pro" : "free");

  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO billing_entitlements (
         user_id, stripe_customer_id, stripe_subscription_id, status, tier, updated_at
       ) VALUES ($1, $2, $3, $4, $5, now())
       ON CONFLICT (user_id) DO UPDATE SET
         stripe_customer_id = COALESCE(EXCLUDED.stripe_customer_id, billing_entitlements.stripe_customer_id),
         stripe_subscription_id = COALESCE(EXCLUDED.stripe_subscription_id, billing_entitlements.stripe_subscription_id),
         status = EXCLUDED.status,
         tier = EXCLUDED.tier,
         updated_at = now()`,
      [
        input.userId,
        input.stripeCustomerId ?? null,
        input.stripeSubscriptionId ?? null,
        input.status,
        tier,
      ],
    );
    const record = await getServerBillingRecord(input.userId);
    if (!record) throw new Error("billing_upsert_failed");
    return record;
  }

  const record: ServerBillingRecord = {
    userId: input.userId,
    stripeCustomerId: input.stripeCustomerId ?? null,
    stripeSubscriptionId: input.stripeSubscriptionId ?? null,
    status: input.status,
    tier,
    updatedAt: new Date().toISOString(),
  };
  memoryMap().set(input.userId, record);
  return record;
}

export async function revokeServerBilling(userId: string): Promise<void> {
  await upsertServerBillingRecord({
    userId,
    status: "canceled",
    tier: "free",
    stripeSubscriptionId: null,
  });
}

export async function deleteServerBilling(userId: string): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(`DELETE FROM billing_entitlements WHERE user_id = $1`, [userId]);
    return result.rowCount ?? 0;
  }
  return memoryMap().delete(userId) ? 1 : 0;
}

/** Non-Postgres billing has no filesystem persistence — always memory. */
export function currentBillingStorageMode(): "postgres" | "memory" {
  return shouldUsePostgresStorage() ? "postgres" : "memory";
}

export async function resolveServerEntitlements(userId: string): Promise<{
  tier: "free" | "pro";
  entitlements: EntitlementId[];
  source: "paid" | "revenuecat" | "free_tier";
}> {
  const record = await getServerBillingRecord(userId);
  if (record && isPaidStatus(record.status) && record.tier === "pro") {
    return {
      tier: "pro",
      entitlements: entitlementsForTier("pro"),
      source: "paid",
    };
  }

  const revenueCat = await resolveRevenueCatSubscriberEntitlements(userId);
  if (revenueCat?.tier === "pro") {
    return {
      tier: "pro",
      entitlements: revenueCat.entitlements,
      source: "revenuecat",
    };
  }

  return {
    tier: "free",
    entitlements: entitlementsForTier("free"),
    source: "free_tier",
  };
}
