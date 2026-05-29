import type Stripe from "stripe";

import {
  revokeServerBilling,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";
import { claimStripeWebhookEvent } from "@/lib/server/webhook-idempotency";

export function userIdFromStripeMetadata(
  meta: Stripe.Metadata | null | undefined,
): string | null {
  const id = meta?.userId;
  return typeof id === "string" && id.length > 0 ? id : null;
}

export async function handleStripeSubscription(
  subscription: Stripe.Subscription,
  status: Stripe.Subscription.Status,
): Promise<void> {
  const userId =
    userIdFromStripeMetadata(subscription.metadata) ??
    userIdFromStripeMetadata(subscription.items.data[0]?.price?.metadata);

  if (!userId) return;

  const paid = status === "active" || status === "trialing";
  await upsertServerBillingRecord({
    userId,
    stripeCustomerId:
      typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer?.id ?? null,
    stripeSubscriptionId: subscription.id,
    status: status as "active" | "trialing" | "past_due" | "canceled" | "unpaid" | "incomplete",
    tier: paid ? "pro" : "free",
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

export async function processStripeWebhookEvent(
  event: Stripe.Event,
  retrieveSubscription: (id: string) => Promise<Stripe.Subscription>,
): Promise<{ processed: boolean; skippedDuplicate: boolean }> {
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
        await handleStripeSubscription(sub, sub.status);
      }
      break;
    }
    case "customer.subscription.updated":
    case "customer.subscription.created": {
      const sub = event.data.object as Stripe.Subscription;
      await handleStripeSubscription(sub, sub.status);
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = userIdFromStripeMetadata(sub.metadata);
      if (userId) await revokeServerBilling(userId);
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
      }
      break;
    }
    default:
      break;
  }

  return { processed: true, skippedDuplicate: false };
}
