import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { MonetizationPlanId } from "@/lib/server/monetization-policy";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";

export type BillingProvider = "stripe" | "revenuecat";
export type AuthoritativeEntitlementStatus =
  | "active"
  | "trialing"
  | "inactive"
  | "expired"
  | "billing_issue";

export interface AuthoritativeEntitlementState {
  userId: string;
  provider: BillingProvider;
  status: AuthoritativeEntitlementStatus;
  planId: MonetizationPlanId;
  periodStart: string | null;
  periodEnd: string | null;
  lifetime: boolean;
  providerEventTimestamp: string;
  updatedAt: string;
}

const memory = globalThis as typeof globalThis & {
  __vmAuthoritativeEntitlements?: Map<string, AuthoritativeEntitlementState>;
  __vmRevenueCatWebhookEvents?: Set<string>;
};

function memoryStates(): Map<string, AuthoritativeEntitlementState> {
  if (!memory.__vmAuthoritativeEntitlements) {
    memory.__vmAuthoritativeEntitlements = new Map();
  }
  return memory.__vmAuthoritativeEntitlements;
}

function key(userId: string, provider: BillingProvider): string {
  return `${userId}\0${provider}`;
}

function memoryWebhookEvents(): Set<string> {
  if (!memory.__vmRevenueCatWebhookEvents) {
    memory.__vmRevenueCatWebhookEvents = new Set();
  }
  return memory.__vmRevenueCatWebhookEvents;
}

export async function upsertAuthoritativeEntitlementState(input: {
  userId: string;
  provider: BillingProvider;
  status: AuthoritativeEntitlementStatus;
  planId: MonetizationPlanId;
  periodStart?: Date | null;
  periodEnd?: Date | null;
  lifetime?: boolean;
  providerEventTimestamp: Date;
}): Promise<AuthoritativeEntitlementState> {
  await assertAccountDeletionNotPending(input.userId);
  if (
    !Number.isFinite(input.providerEventTimestamp.getTime()) ||
    (input.periodStart && !Number.isFinite(input.periodStart.getTime())) ||
    (input.periodEnd && !Number.isFinite(input.periodEnd.getTime())) ||
    (input.periodStart && input.periodEnd && input.periodEnd <= input.periodStart)
  ) {
    throw new Error("AUTHORITATIVE_ENTITLEMENT_INVALID");
  }

  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO billing_entitlement_sources
       (user_id, provider, status, plan_id, period_start, period_end, lifetime,
        provider_event_timestamp, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,now())
       ON CONFLICT (user_id, provider) DO UPDATE SET
         status = EXCLUDED.status,
         plan_id = EXCLUDED.plan_id,
         period_start = EXCLUDED.period_start,
         period_end = EXCLUDED.period_end,
         lifetime = EXCLUDED.lifetime,
         provider_event_timestamp = EXCLUDED.provider_event_timestamp,
         updated_at = now()
       WHERE billing_entitlement_sources.provider_event_timestamp <=
             EXCLUDED.provider_event_timestamp`,
      [
        input.userId,
        input.provider,
        input.status,
        input.planId,
        input.periodStart ?? null,
        input.periodEnd ?? null,
        input.lifetime ?? false,
        input.providerEventTimestamp,
      ],
    );
    const state = await getAuthoritativeEntitlementState(
      input.userId,
      input.provider,
    );
    if (!state) throw new Error("AUTHORITATIVE_ENTITLEMENT_UPSERT_FAILED");
    return state;
  }

  const existing = memoryStates().get(key(input.userId, input.provider));
  if (
    existing &&
    Date.parse(existing.providerEventTimestamp) >
      input.providerEventTimestamp.getTime()
  ) {
    return existing;
  }
  const state: AuthoritativeEntitlementState = {
    userId: input.userId,
    provider: input.provider,
    status: input.status,
    planId: input.planId,
    periodStart: input.periodStart?.toISOString() ?? null,
    periodEnd: input.periodEnd?.toISOString() ?? null,
    lifetime: input.lifetime ?? false,
    providerEventTimestamp: input.providerEventTimestamp.toISOString(),
    updatedAt: new Date().toISOString(),
  };
  memoryStates().set(key(input.userId, input.provider), state);
  return state;
}

export async function getAuthoritativeEntitlementState(
  userId: string,
  provider: BillingProvider,
): Promise<AuthoritativeEntitlementState | null> {
  if (!shouldUsePostgresStorage()) {
    return memoryStates().get(key(userId, provider)) ?? null;
  }
  const result = await dbQuery<{
    user_id: string;
    provider: BillingProvider;
    status: AuthoritativeEntitlementStatus;
    plan_id: MonetizationPlanId;
    period_start: Date | null;
    period_end: Date | null;
    lifetime: boolean;
    provider_event_timestamp: Date;
    updated_at: Date;
  }>(
    `SELECT user_id, provider, status, plan_id, period_start, period_end,
            lifetime, provider_event_timestamp, updated_at
     FROM billing_entitlement_sources
     WHERE user_id = $1 AND provider = $2`,
    [userId, provider],
  );
  const row = result.rows[0];
  return row
    ? {
        userId: row.user_id,
        provider: row.provider,
        status: row.status,
        planId: row.plan_id,
        periodStart: row.period_start?.toISOString() ?? null,
        periodEnd: row.period_end?.toISOString() ?? null,
        lifetime: row.lifetime,
        providerEventTimestamp: row.provider_event_timestamp.toISOString(),
        updatedAt: row.updated_at.toISOString(),
      }
    : null;
}

export async function claimRevenueCatWebhookEvent(
  eventId: string,
): Promise<boolean> {
  if (!eventId.trim()) throw new Error("REVENUECAT_EVENT_ID_INVALID");
  if (!shouldUsePostgresStorage()) {
    if (memoryWebhookEvents().has(eventId)) return false;
    memoryWebhookEvents().add(eventId);
    return true;
  }
  const result = await dbQuery(
    `INSERT INTO revenuecat_webhook_events (event_id)
     VALUES ($1) ON CONFLICT (event_id) DO NOTHING`,
    [eventId],
  );
  return (result.rowCount ?? 0) > 0;
}

export function resetAuthoritativeEntitlementsForTests(): void {
  memoryStates().clear();
  memoryWebhookEvents().clear();
}
