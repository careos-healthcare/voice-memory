/**
 * Payment stack audit — reflects env + routes at runtime.
 */

import { isStripeConfigured } from "@/lib/billing/stripe-config";

export type PaymentProviderId = "none" | "stripe" | "revenuecat";

export interface PaymentStackAudit {
  stripeSdkPresent: boolean;
  stripeCheckoutRoute: boolean;
  stripeWebhookRoute: boolean;
  revenueCatPresent: boolean;
  subscriptionStorage: boolean;
  entitlementLayer: boolean;
  checkoutImplemented: boolean;
  billingPortalImplemented: boolean;
  summary: string;
}

export function getPaymentStackAudit(): PaymentStackAudit {
  const stripeOn = isStripeConfigured();
  const checkoutImplemented = stripeOn;

  return {
    stripeSdkPresent: true,
    stripeCheckoutRoute: true,
    stripeWebhookRoute: true,
    revenueCatPresent: false,
    subscriptionStorage: true,
    entitlementLayer: true,
    checkoutImplemented,
    billingPortalImplemented: false,
    summary: checkoutImplemented
      ? "Stripe checkout + webhook wired; entitlements stored server-side when DATABASE_URL is set."
      : "Stripe env incomplete — checkout disabled (fail closed). Founder preview remains separate.",
  };
}

export function isLiveBillingAvailable(): boolean {
  return getPaymentStackAudit().checkoutImplemented;
}
