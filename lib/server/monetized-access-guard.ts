import "server-only";

import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";

import { getServerBillingRecord } from "@/lib/server/billing-entitlements";
import {
  getMonetizationCapability,
  type MonetizationCapabilityId,
  type MonetizationPlanId,
} from "@/lib/server/monetization-policy";
import { getRevenueCatUserMapping } from "@/lib/server/revenuecat-mapping";
import { verifyRevenueCatEntitlement } from "@/lib/server/revenuecat-verifier";
import {
  UsageAllowanceConfigurationError,
  usageAllowanceFor,
} from "@/lib/server/usage-allowance-config";
import {
  reserveUsage,
  type UsageReservation,
} from "@/lib/server/usage-reservation-store";
import {
  getAuthoritativeEntitlementState,
  upsertAuthoritativeEntitlementState,
  type AuthoritativeEntitlementState,
} from "@/lib/server/authoritative-entitlement-store";

export interface MonetizedAccessContext {
  userId: string;
  planId: MonetizationPlanId;
  capabilityId: MonetizationCapabilityId;
  entitlementSource: "stripe" | "revenuecat" | "free" | "unknown";
  reservation?: UsageReservation;
}

export type MonetizedAccessResult =
  | { ok: true; ctx: MonetizedAccessContext }
  | { ok: false; response: NextResponse };

export type MonetizedAccessErrorCode =
  | "AUTH_REQUIRED"
  | "ENTITLEMENT_UNKNOWN"
  | "ENTITLEMENT_REQUIRED"
  | "USAGE_ALLOWANCE_CONFIG_INVALID"
  | "IDEMPOTENCY_REQUIRED"
  | "USAGE_ALLOWANCE_REACHED"
  | "IDEMPOTENCY_REPLAY"
  | "REQUEST_IN_PROGRESS";

const ROUTE_CAPABILITIES: ReadonlyArray<
  readonly [string, MonetizationCapabilityId]
> = [
  ["/api/transcribe", "remoteTranscription"],
  ["/api/analyze", "remoteObservationGeneration"],
];

export function capabilityForExpensiveRoute(
  request: Request,
): MonetizationCapabilityId {
  const pathname = new URL(request.url).pathname.replace(/\/+$/, "");
  const capability = ROUTE_CAPABILITIES.find(
    ([route]) => pathname === route,
  )?.[1];
  if (!capability) throw new Error("MONETIZATION_ROUTE_POLICY_MISSING");
  return capability;
}

function response(
  status: 400 | 401 | 402 | 409 | 429 | 503,
  code: MonetizedAccessErrorCode,
  error: string,
  extra?: Record<string, number | string>,
): MonetizedAccessResult {
  return {
    ok: false,
    response: NextResponse.json(
      { error, code, preserveLocalContent: true, ...extra },
      { status },
    ),
  };
}

function utcMonthPeriod(now: Date): { start: Date; end: Date } {
  return {
    start: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
    end: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)),
  };
}

async function resolvePlan(userId: string): Promise<{
  planId: MonetizationPlanId;
  source: MonetizedAccessContext["entitlementSource"];
  period?: { start: Date; end: Date };
}> {
  const [stripeState, revenueCatState, stripe] = await Promise.all([
    getAuthoritativeEntitlementState(userId, "stripe"),
    getAuthoritativeEntitlementState(userId, "revenuecat"),
    getServerBillingRecord(userId),
  ]);
  const now = new Date();
  const activeSource = (
    state: AuthoritativeEntitlementState | null,
  ): state is AuthoritativeEntitlementState =>
    Boolean(
      state &&
      (state.status === "active" ||
        state.status === "trialing" ||
        state.status === "billing_issue") &&
      (state.lifetime || (state.periodEnd && new Date(state.periodEnd) > now)),
    );
  const resolvedSource = activeSource(stripeState)
    ? stripeState
    : activeSource(revenueCatState)
      ? revenueCatState
      : null;
  if (resolvedSource) {
    const start = resolvedSource.periodStart
      ? new Date(resolvedSource.periodStart)
      : null;
    const end = resolvedSource.periodEnd
      ? new Date(resolvedSource.periodEnd)
      : null;
    return {
      planId: resolvedSource.planId,
      source: resolvedSource.provider,
      ...(start && end && end > start ? { period: { start, end } } : {}),
    };
  }

  if (
    !stripeState &&
    stripe?.tier === "pro" &&
    (stripe.status === "active" || stripe.status === "trialing")
  ) {
    const start = stripe.billingPeriodStart
      ? new Date(stripe.billingPeriodStart)
      : null;
    const end = stripe.subscriptionEndDate
      ? new Date(stripe.subscriptionEndDate)
      : null;
    return {
      planId: "pro_subscription",
      source: "stripe",
      ...(start && end && end > start ? { period: { start, end } } : {}),
    };
  }

  // Once a RevenueCat webhook has established authoritative state, do not let
  // a later live-read response overwrite an expiry, refund, or revocation.
  // Webhooks remain the source of truth until a newer webhook event arrives.
  if (revenueCatState) {
    return { planId: "free", source: "revenuecat" };
  }

  const mapping = await getRevenueCatUserMapping(userId);
  if (mapping) {
    const verified = await verifyRevenueCatEntitlement(mapping.appUserId);
    if (verified.status === "verified" && verified.active) {
      const start = verified.periodStart
        ? new Date(verified.periodStart)
        : null;
      const end = verified.periodEnd ? new Date(verified.periodEnd) : null;
      const planId = verified.lifetime
        ? "legacy_grandfathered"
        : "pro_subscription";
      await upsertAuthoritativeEntitlementState({
        userId,
        provider: "revenuecat",
        status: "active",
        planId,
        periodStart: start,
        periodEnd: end,
        lifetime: verified.lifetime,
        providerEventTimestamp: new Date(verified.checkedAt),
      });
      return {
        planId,
        source: "revenuecat",
        ...(start && end && end > start ? { period: { start, end } } : {}),
      };
    }
    if (verified.status === "unavailable") {
      return { planId: "free", source: "unknown" };
    }
  }
  return { planId: "free", source: "free" };
}

export async function requireMonetizedAccess(input: {
  userId?: string;
  capabilityId: MonetizationCapabilityId;
  idempotencyKey?: string | null;
  requestedUnits?: number;
  now?: Date;
}): Promise<MonetizedAccessResult> {
  if (!input.userId) {
    return response(
      401,
      "AUTH_REQUIRED",
      "Sign in before using remote processing.",
    );
  }
  const capability = getMonetizationCapability(input.capabilityId);
  const plan = await resolvePlan(input.userId);
  if (plan.source === "unknown") {
    return response(
      503,
      "ENTITLEMENT_UNKNOWN",
      "Subscription state is temporarily unavailable.",
    );
  }
  const proRequired =
    capability.accessClass === "pro" || capability.accessClass === "proMetered";
  if (proRequired && plan.planId === "free") {
    return response(
      402,
      "ENTITLEMENT_REQUIRED",
      "An active Pro subscription is required for this operation.",
    );
  }

  if (!capability.usageMeterId) {
    return {
      ok: true,
      ctx: {
        userId: input.userId,
        planId: plan.planId,
        capabilityId: input.capabilityId,
        entitlementSource: plan.source,
      },
    };
  }

  let allowance: number;
  try {
    allowance = usageAllowanceFor(plan.planId, capability.usageMeterId);
  } catch (error) {
    if (
      process.env.NODE_ENV !== "production" &&
      error instanceof UsageAllowanceConfigurationError
    ) {
      return {
        ok: true,
        ctx: {
          userId: input.userId,
          planId: plan.planId,
          capabilityId: input.capabilityId,
          entitlementSource: plan.source,
        },
      };
    }
    return response(
      503,
      "USAGE_ALLOWANCE_CONFIG_INVALID",
      "This remote operation is not configured on the server.",
    );
  }

  const idempotencyKey = input.idempotencyKey?.trim();
  if (!idempotencyKey && process.env.NODE_ENV === "production") {
    return response(
      409,
      "IDEMPOTENCY_REQUIRED",
      "An idempotency key is required for remote processing.",
    );
  }
  if (
    plan.planId === "pro_subscription" &&
    !plan.period &&
    process.env.NODE_ENV === "production"
  ) {
    return response(
      503,
      "USAGE_ALLOWANCE_CONFIG_INVALID",
      "The trusted billing period is unavailable for this operation.",
    );
  }
  const period = plan.period ?? utcMonthPeriod(input.now ?? new Date());
  const reserved = await reserveUsage({
    userId: input.userId,
    planId: plan.planId,
    capabilityId: input.capabilityId,
    meterId: capability.usageMeterId,
    periodStart: period.start,
    periodEnd: period.end,
    units: input.requestedUnits ?? 1,
    allowance,
    idempotencyKey: idempotencyKey || randomUUID(),
  });
  if (!reserved.allowed) {
    return response(
      429,
      "USAGE_ALLOWANCE_REACHED",
      "The usage allowance for this billing period has been reached.",
      {
        meterId: capability.usageMeterId,
        used: reserved.used,
        requested: reserved.requested,
        allowance: reserved.allowance,
        periodEnd: period.end.toISOString(),
      },
    );
  }
  if (reserved.duplicate) {
    return response(
      409,
      reserved.reservation.status === "committed"
        ? "IDEMPOTENCY_REPLAY"
        : "REQUEST_IN_PROGRESS",
      reserved.reservation.status === "committed"
        ? "This metered operation was already committed."
        : "This metered operation is already in progress.",
    );
  }
  return {
    ok: true,
    ctx: {
      userId: input.userId,
      planId: plan.planId,
      capabilityId: input.capabilityId,
      entitlementSource: plan.source,
      reservation: reserved.reservation,
    },
  };
}
