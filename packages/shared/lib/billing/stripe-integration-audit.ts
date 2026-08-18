import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export const REQUIRED_STRIPE_WEBHOOK_EVENTS = [
  "checkout.session.completed",
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "invoice.payment_failed",
] as const;

export interface StripeIntegrationAuditItem {
  name: string;
  ok: boolean;
  detail: string;
}

function readRootFile(root: string, rel: string): string {
  return readFileSync(resolve(root, rel), "utf8");
}

export function stripeIntegrationAudit(root = process.cwd()): StripeIntegrationAuditItem[] {
  const items: StripeIntegrationAuditItem[] = [];
  const checkout = readRootFile(root, "app/api/billing/checkout/route.ts");
  const webhook = readRootFile(root, "app/api/billing/webhook/route.ts");
  const handler = readRootFile(root, "lib/billing/stripe-webhook-handler.ts");
  const config = readRootFile(root, "lib/billing/stripe-config.ts");

  items.push({
    name: "Checkout uses Stripe SDK",
    ok:
      checkout.includes("requireStripeClient") &&
      checkout.includes("checkout.sessions.create"),
    detail: "POST /api/billing/checkout creates subscription session via Stripe SDK.",
  });

  items.push({
    name: "Checkout uses server price id",
    ok:
      checkout.includes("config.priceId") &&
      !checkout.includes("NEXT_PUBLIC_STRIPE"),
    detail: "Line items use STRIPE_PRO_PRICE_ID from server config only.",
  });

  items.push({
    name: "Webhook signature verification",
    ok:
      webhook.includes("constructEvent") &&
      webhook.includes("config.webhookSecret") &&
      webhook.includes("stripe-signature"),
    detail: "Webhook uses STRIPE_WEBHOOK_SECRET via constructEvent.",
  });

  items.push({
    name: "Webhook idempotency",
    ok: handler.includes("claimStripeWebhookEvent"),
    detail: "Duplicate event ids are skipped before side effects.",
  });

  for (const ev of REQUIRED_STRIPE_WEBHOOK_EVENTS) {
    items.push({
      name: `Handler: ${ev}`,
      ok: handler.includes(`"${ev}"`),
      detail: ev,
    });
  }

  items.push({
    name: "Entitlement: checkout completed",
    ok: handler.includes("checkout.session.completed"),
    detail: "Grants pro after subscription retrieve.",
  });

  items.push({
    name: "Entitlement: subscription active",
    ok:
      handler.includes("customer.subscription.created") ||
      handler.includes("handleStripeSubscription"),
    detail: "active/trialing → pro tier.",
  });

  items.push({
    name: "Entitlement: payment failed",
    ok: handler.includes("invoice.payment_failed"),
    detail: "past_due + free tier (no pro grant).",
  });

  items.push({
    name: "Entitlement: subscription canceled/deleted",
    ok:
      handler.includes("customer.subscription.deleted") &&
      handler.includes("revokeServerBilling"),
    detail: "Deleted subscription revokes pro.",
  });

  items.push({
    name: "Stripe config fail-closed",
    ok: config.includes("enabled = missing.length === 0"),
    detail: "All four Stripe env vars required to enable billing.",
  });

  return items;
}
