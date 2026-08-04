import type Stripe from "stripe";

import {
  revokeServerBilling,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";
import {
  claimStripeWebhookEvent,
  isStripeWebhookEventClaimed,
} from "@/lib/server/webhook-idempotency";
import { isUnitEconomicsEnabled } from "@/lib/server/unit-economics-config";
import { meterMoneyBestEffort } from "@/lib/server/unit-economics-meter";
import { upsertAuthoritativeEntitlementState } from "@/lib/server/authoritative-entitlement-store";

export function userIdFromStripeMetadata(
  meta: Stripe.Metadata | null | undefined,
): string | null {
  const id = meta?.userId;
  return typeof id === "string" && id.length > 0 ? id : null;
}

function stripeEventTimestamp(event: Stripe.Event): Date {
  return Number.isFinite(event.created) && event.created > 0
    ? new Date(event.created * 1_000)
    : new Date();
}

export async function handleStripeSubscription(
  subscription: Stripe.Subscription,
  status: Stripe.Subscription.Status,
  providerEventTimestamp = new Date(),
): Promise<void> {
  const userId =
    userIdFromStripeMetadata(subscription.metadata) ??
    userIdFromStripeMetadata(subscription.items.data[0]?.price?.metadata);

  if (!userId) return;

  const paid = status === "active" || status === "trialing";
  const periodEnd =
    Number.isFinite(subscription.current_period_end) &&
    subscription.current_period_end > 0
      ? new Date(subscription.current_period_end * 1_000)
      : null;
  const periodStart =
    Number.isFinite(subscription.current_period_start) &&
    subscription.current_period_start > 0
      ? new Date(subscription.current_period_start * 1_000)
      : null;
  await upsertServerBillingRecord({
    userId,
    stripeCustomerId:
      typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer?.id ?? null,
    stripeSubscriptionId: subscription.id,
    status: status as "active" | "trialing" | "past_due" | "canceled" | "unpaid" | "incomplete",
    tier: paid ? "pro" : "free",
    billingPeriodStart: periodStart,
    subscriptionEndDate: periodEnd,
  });
  await upsertAuthoritativeEntitlementState({
    userId,
    provider: "stripe",
    status:
      status === "active"
        ? "active"
        : status === "trialing"
          ? "trialing"
          : status === "past_due" || status === "unpaid"
            ? "billing_issue"
            : "inactive",
    planId: paid ? "pro_subscription" : "free",
    periodStart,
    periodEnd,
    providerEventTimestamp,
  });
}

function userIdFromCheckoutSession(session: Stripe.Checkout.Session): string | null {
  return (
    userIdFromStripeMetadata(session.metadata) ??
    (typeof session.client_reference_id === "string" && session.client_reference_id.length > 0
      ? session.client_reference_id
      : null)
  );
}

async function userIdFromInvoice(
  invoice: Stripe.Invoice,
  retrieveSubscription: (id: string) => Promise<Stripe.Subscription>,
): Promise<string | null> {
  const fromMeta = userIdFromStripeMetadata(invoice.metadata);
  if (fromMeta) return fromMeta;

  const subRef = invoice.subscription;
  const subId =
    typeof subRef === "string" ? subRef : subRef && typeof subRef === "object" ? subRef.id : null;
  if (!subId) return null;

  const sub = await retrieveSubscription(subId);
  return userIdFromStripeMetadata(sub.metadata);
}

export function stripeInvoiceAmountMicroUsd(invoice: Stripe.Invoice): bigint {
  if (invoice.currency?.toLowerCase() !== "usd") {
    throw new Error("STRIPE_REVENUE_CURRENCY_UNSUPPORTED");
  }
  if (!Number.isSafeInteger(invoice.amount_paid) || invoice.amount_paid < 0) {
    throw new Error("STRIPE_REVENUE_AMOUNT_INVALID");
  }
  const amountMicroUsd = BigInt(invoice.amount_paid) * 10_000n;
  if (amountMicroUsd > 9_223_372_036_854_775_807n) {
    throw new Error("STRIPE_REVENUE_AMOUNT_INVALID");
  }
  return amountMicroUsd;
}

async function meterPaidInvoice(
  event: Stripe.Event,
  invoice: Stripe.Invoice,
  retrieveSubscription: (id: string) => Promise<Stripe.Subscription>,
): Promise<void> {
  const amountMicroUsd = stripeInvoiceAmountMicroUsd(invoice);
  const userId = await userIdFromInvoice(invoice, retrieveSubscription);
  if (!userId) throw new Error("STRIPE_REVENUE_SUBJECT_UNRESOLVED");
  const paidAtSeconds = invoice.status_transitions?.paid_at ?? event.created;
  const recorded = await meterMoneyBestEffort({
    operation: "stripe.invoice-paid",
    subject: { kind: "user", id: userId },
    idempotencyKey: event.id,
    metric: "revenue",
    amountMicroUsd,
    resource: "stripe.subscription",
    dimensions: { provider: "stripe", plan: "pro" },
    occurredAt: new Date(paidAtSeconds * 1_000),
  });
  if (!recorded && isUnitEconomicsEnabled()) {
    throw new Error("STRIPE_REVENUE_ACCOUNTING_FAILED");
  }
}

export async function processStripeWebhookEvent(
  event: Stripe.Event,
  retrieveSubscription: (id: string) => Promise<Stripe.Subscription>,
): Promise<{ processed: boolean; skippedDuplicate: boolean }> {
  if (event.type === "invoice.paid") {
    if (await isStripeWebhookEventClaimed(event.id)) {
      return { processed: false, skippedDuplicate: true };
    }
    const invoice = event.data.object as Stripe.Invoice;
    if (isUnitEconomicsEnabled()) {
      // Meter first: a failed append must leave the webhook retryable. The
      // ledger event key makes a later retry safe if claiming fails afterward.
      await meterPaidInvoice(event, invoice, retrieveSubscription);
    }
    const claimedPaidInvoice = await claimStripeWebhookEvent(event.id);
    if (!claimedPaidInvoice) {
      return { processed: false, skippedDuplicate: true };
    }
    return { processed: true, skippedDuplicate: false };
  }

  const claimed = await claimStripeWebhookEvent(event.id);
  if (!claimed) {
    return { processed: false, skippedDuplicate: true };
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = userIdFromCheckoutSession(session);
      if (userId && session.subscription && typeof session.subscription === "string") {
        const sub = await retrieveSubscription(session.subscription);
        await handleStripeSubscription(
          sub,
          sub.status,
          stripeEventTimestamp(event),
        );
      }
      break;
    }
    case "customer.subscription.updated":
    case "customer.subscription.created": {
      const sub = event.data.object as Stripe.Subscription;
      await handleStripeSubscription(
        sub,
        sub.status,
        stripeEventTimestamp(event),
      );
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = userIdFromStripeMetadata(sub.metadata);
      if (userId) {
        const endedAt = sub.ended_at ?? sub.current_period_end;
        const periodEnd =
          Number.isFinite(endedAt) && endedAt > 0
            ? new Date(endedAt * 1_000)
            : null;
        await revokeServerBilling(
          userId,
          periodEnd,
        );
        await upsertAuthoritativeEntitlementState({
          userId,
          provider: "stripe",
          status: "inactive",
          planId: "free",
          periodEnd,
          providerEventTimestamp: stripeEventTimestamp(event),
        });
      }
      break;
    }
    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      const userId = await userIdFromInvoice(invoice, retrieveSubscription);
      if (userId) {
        await upsertServerBillingRecord({
          userId,
          status: "past_due",
          tier: "free",
        });
        await upsertAuthoritativeEntitlementState({
          userId,
          provider: "stripe",
          status: "billing_issue",
          planId: "free",
          providerEventTimestamp: stripeEventTimestamp(event),
        });
      }
      break;
    }
    default:
      break;
  }

  return { processed: true, skippedDuplicate: false };
}
