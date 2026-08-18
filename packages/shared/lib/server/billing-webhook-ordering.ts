import "server-only";

import type { BillingSubscriptionStatus } from "@/lib/server/billing-entitlements";

const STATUS_RANK: Record<BillingSubscriptionStatus, number> = {
  active: 4,
  trialing: 4,
  past_due: 2,
  incomplete: 1,
  unpaid: 1,
  canceled: 0,
};

const globalWebhookState = globalThis as typeof globalThis & {
  __vmBillingWebhookEventAt?: Map<string, number>;
};

function webhookEventMap(): Map<string, number> {
  if (!globalWebhookState.__vmBillingWebhookEventAt) {
    globalWebhookState.__vmBillingWebhookEventAt = new Map();
  }
  return globalWebhookState.__vmBillingWebhookEventAt;
}

export function readLastWebhookEventCreatedAt(userId: string): number | null {
  return webhookEventMap().get(userId) ?? null;
}

export function rememberWebhookEventCreatedAt(
  userId: string,
  eventCreatedAt: number,
): void {
  const existing = webhookEventMap().get(userId);
  if (existing == null || eventCreatedAt >= existing) {
    webhookEventMap().set(userId, eventCreatedAt);
  }
}

export function shouldApplyBillingWebhookUpdate(input: {
  userId: string;
  incomingStatus: BillingSubscriptionStatus;
  existingStatus: BillingSubscriptionStatus | null;
  eventCreatedAt: number;
}): { apply: boolean; reason?: string } {
  const lastEventAt = readLastWebhookEventCreatedAt(input.userId);
  if (lastEventAt != null && input.eventCreatedAt < lastEventAt) {
    return {
      apply: false,
      reason: "stale_webhook_event",
    };
  }

  if (input.existingStatus == null) {
    return { apply: true };
  }

  const incomingRank = STATUS_RANK[input.incomingStatus];
  const existingRank = STATUS_RANK[input.existingStatus];
  if (incomingRank < existingRank && lastEventAt === input.eventCreatedAt) {
    return {
      apply: false,
      reason: "duplicate_downgrade_event",
    };
  }

  return { apply: true };
}
