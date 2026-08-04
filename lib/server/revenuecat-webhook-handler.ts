import { timingSafeEqual } from "node:crypto";

import {
  claimRevenueCatWebhookEvent,
  upsertAuthoritativeEntitlementState,
  type AuthoritativeEntitlementStatus,
} from "@/lib/server/authoritative-entitlement-store";
import {
  REVENUECAT_LEGACY_GRANDFATHERED_PRODUCT_IDS,
  REVENUECAT_PRO_ENTITLEMENT_IDS,
  type MonetizationPlanId,
} from "@/lib/server/monetization-policy";
import { getRevenueCatMappingByAppUserId } from "@/lib/server/revenuecat-mapping";

export type RevenueCatWebhookResult =
  | { ok: true; duplicate: boolean; ignored: boolean }
  | {
      ok: false;
      status: 400 | 401 | 409 | 503;
      code:
        | "REVENUECAT_WEBHOOK_NOT_CONFIGURED"
        | "REVENUECAT_WEBHOOK_UNAUTHORIZED"
        | "REVENUECAT_WEBHOOK_INVALID"
        | "REVENUECAT_USER_MAPPING_REQUIRED";
    };

function constantTimeEqual(actual: string, expected: string): boolean {
  const left = Buffer.from(actual);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

export function authorizeRevenueCatWebhook(
  authorization: string | null,
  configuredToken = process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN?.trim(),
): Extract<RevenueCatWebhookResult, { ok: false }> | null {
  if (!configuredToken) {
    return {
      ok: false,
      status: 503,
      code: "REVENUECAT_WEBHOOK_NOT_CONFIGURED",
    };
  }
  const actual = authorization?.replace(/^Bearer\s+/i, "").trim() ?? "";
  if (!actual || !constantTimeEqual(actual, configuredToken)) {
    return {
      ok: false,
      status: 401,
      code: "REVENUECAT_WEBHOOK_UNAUTHORIZED",
    };
  }
  return null;
}

type ParsedRevenueCatEvent = {
  eventId: string;
  eventType: string;
  appUserId: string;
  eventAt: Date;
  periodStart: Date | null;
  periodEnd: Date | null;
  lifetime: boolean;
  hasProEntitlement: boolean;
};

function dateFromMilliseconds(value: unknown): Date | null {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0) {
    return null;
  }
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date : null;
}

function parseEvent(payload: unknown): ParsedRevenueCatEvent | null {
  if (!payload || typeof payload !== "object") return null;
  const event = (payload as { event?: unknown }).event;
  if (!event || typeof event !== "object") return null;
  const value = event as Record<string, unknown>;
  const eventId = typeof value.id === "string" ? value.id.trim() : "";
  const eventType = typeof value.type === "string" ? value.type.trim() : "";
  const appUserId =
    typeof value.app_user_id === "string" ? value.app_user_id.trim() : "";
  const eventAt =
    dateFromMilliseconds(value.event_timestamp_ms) ??
    dateFromMilliseconds(value.purchased_at_ms);
  if (!eventId || !eventType || !appUserId || !eventAt) return null;
  const entitlementIds = Array.isArray(value.entitlement_ids)
    ? value.entitlement_ids.filter(
        (candidate): candidate is string => typeof candidate === "string",
      )
    : [];
  const periodStart = dateFromMilliseconds(value.purchased_at_ms);
  const periodEnd = dateFromMilliseconds(value.expiration_at_ms);
  const productId =
    typeof value.product_id === "string" ? value.product_id.trim() : "";
  return {
    eventId,
    eventType,
    appUserId,
    eventAt,
    periodStart,
    periodEnd,
    lifetime:
      value.expiration_at_ms === null &&
      eventType === "NON_RENEWING_PURCHASE" &&
      REVENUECAT_LEGACY_GRANDFATHERED_PRODUCT_IDS.some(
        (candidate) => candidate === productId,
      ),
    hasProEntitlement: entitlementIds.some((id) =>
      REVENUECAT_PRO_ENTITLEMENT_IDS.includes(
        id as (typeof REVENUECAT_PRO_ENTITLEMENT_IDS)[number],
      ),
    ),
  };
}

function stateFromEvent(event: ParsedRevenueCatEvent): {
  status: AuthoritativeEntitlementStatus;
  planId: MonetizationPlanId;
} | null {
  if (!event.hasProEntitlement) return null;
  if (event.lifetime) {
    return { status: "active", planId: "legacy_grandfathered" };
  }
  if (event.eventType === "BILLING_ISSUE") {
    return { status: "billing_issue", planId: "pro_subscription" };
  }
  if (
    event.eventType === "EXPIRATION" ||
    event.eventType === "SUBSCRIPTION_PAUSED" ||
    event.eventType === "REFUND" ||
    event.eventType === "REVOKE" ||
    event.eventType === "REVOCATION"
  ) {
    return { status: "expired", planId: "free" };
  }
  if (event.periodEnd && event.periodEnd <= event.eventAt) {
    return { status: "expired", planId: "free" };
  }
  if (
    [
      "INITIAL_PURCHASE",
      "RENEWAL",
      "PRODUCT_CHANGE",
      "CANCELLATION",
      "UNCANCELLATION",
      "TEMPORARY_ENTITLEMENT_GRANT",
      "NON_RENEWING_PURCHASE",
      "TRANSFER",
    ].includes(event.eventType)
  ) {
    return { status: "active", planId: "pro_subscription" };
  }
  return null;
}

export async function processRevenueCatWebhook(
  payload: unknown,
): Promise<RevenueCatWebhookResult> {
  const event = parseEvent(payload);
  if (!event) {
    return { ok: false, status: 400, code: "REVENUECAT_WEBHOOK_INVALID" };
  }
  const mapping = await getRevenueCatMappingByAppUserId(event.appUserId);
  if (!mapping) {
    return {
      ok: false,
      status: 409,
      code: "REVENUECAT_USER_MAPPING_REQUIRED",
    };
  }
  const next = stateFromEvent(event);
  if (!next) {
    const claimed = await claimRevenueCatWebhookEvent(event.eventId);
    return { ok: true, duplicate: !claimed, ignored: true };
  }
  await upsertAuthoritativeEntitlementState({
    userId: mapping.userId,
    provider: "revenuecat",
    status: next.status,
    planId: next.planId,
    periodStart: event.periodStart,
    periodEnd: event.periodEnd,
    lifetime: event.lifetime,
    providerEventTimestamp: event.eventAt,
  });
  const claimed = await claimRevenueCatWebhookEvent(event.eventId);
  return { ok: true, duplicate: !claimed, ignored: false };
}
