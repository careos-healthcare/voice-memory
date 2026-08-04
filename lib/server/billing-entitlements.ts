import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";
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
  billingPeriodStart: string | null;
  subscriptionEndDate: string | null;
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
      billing_period_start: Date | null;
      subscription_end_date: Date | null;
      updated_at: Date;
    }>(
      `SELECT user_id, stripe_customer_id, stripe_subscription_id, status, tier,
              billing_period_start, subscription_end_date, updated_at
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
      billingPeriodStart: row.billing_period_start?.toISOString() ?? null,
      subscriptionEndDate: row.subscription_end_date?.toISOString() ?? null,
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
  billingPeriodStart?: Date | null;
  subscriptionEndDate?: Date | null;
}): Promise<ServerBillingRecord> {
  await assertAccountDeletionNotPending(input.userId);
  const tier =
    input.tier ?? (isPaidStatus(input.status) ? "pro" : "free");

  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO billing_entitlements (
         user_id, stripe_customer_id, stripe_subscription_id, status, tier,
         billing_period_start, subscription_end_date, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, now())
       ON CONFLICT (user_id) DO UPDATE SET
         stripe_customer_id = COALESCE(EXCLUDED.stripe_customer_id, billing_entitlements.stripe_customer_id),
         stripe_subscription_id = COALESCE(EXCLUDED.stripe_subscription_id, billing_entitlements.stripe_subscription_id),
         status = EXCLUDED.status,
         tier = EXCLUDED.tier,
         billing_period_start = COALESCE(EXCLUDED.billing_period_start, billing_entitlements.billing_period_start),
         subscription_end_date = COALESCE(EXCLUDED.subscription_end_date, billing_entitlements.subscription_end_date),
         updated_at = now()`,
      [
        input.userId,
        input.stripeCustomerId ?? null,
        input.stripeSubscriptionId ?? null,
        input.status,
        tier,
        input.billingPeriodStart ?? null,
        input.subscriptionEndDate ?? null,
      ],
    );
    const record = await getServerBillingRecord(input.userId);
    if (!record) throw new Error("billing_upsert_failed");
    return record;
  }

  const previous = memoryMap().get(input.userId);
  const record: ServerBillingRecord = {
    userId: input.userId,
    stripeCustomerId:
      input.stripeCustomerId ?? previous?.stripeCustomerId ?? null,
    stripeSubscriptionId:
      input.stripeSubscriptionId ?? previous?.stripeSubscriptionId ?? null,
    status: input.status,
    tier,
    billingPeriodStart:
      input.billingPeriodStart?.toISOString() ??
      previous?.billingPeriodStart ??
      null,
    subscriptionEndDate:
      input.subscriptionEndDate?.toISOString() ??
      previous?.subscriptionEndDate ??
      null,
    updatedAt: new Date().toISOString(),
  };
  memoryMap().set(input.userId, record);
  return record;
}

export async function revokeServerBilling(
  userId: string,
  subscriptionEndDate?: Date | null,
): Promise<void> {
  await upsertServerBillingRecord({
    userId,
    status: "canceled",
    tier: "free",
    stripeSubscriptionId: null,
    subscriptionEndDate,
  });
}

export async function deleteServerBilling(userId: string): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM billing_entitlements WHERE user_id = $1`, [userId]);
    return;
  }
  memoryMap().delete(userId);
}

export async function resolveServerEntitlements(userId: string): Promise<{
  tier: "free" | "pro";
  entitlements: EntitlementId[];
  source: "paid" | "free_tier";
}> {
  const record = await getServerBillingRecord(userId);
  if (record && isPaidStatus(record.status) && record.tier === "pro") {
    return {
      tier: "pro",
      entitlements: entitlementsForTier("pro"),
      source: "paid",
    };
  }
  return {
    tier: "free",
    entitlements: entitlementsForTier("free"),
    source: "free_tier",
  };
}
