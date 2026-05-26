/**
 * Payment stack audit — source of truth for what is wired vs copy-only.
 * Update when Stripe or another provider is integrated.
 */

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

/** Static audit — no network calls. Reflects repo state at build time. */
export const PAYMENT_STACK_AUDIT: PaymentStackAudit = {
  stripeSdkPresent: false,
  stripeCheckoutRoute: false,
  stripeWebhookRoute: false,
  revenueCatPresent: false,
  subscriptionStorage: true,
  entitlementLayer: true,
  checkoutImplemented: false,
  billingPortalImplemented: false,
  summary:
    "Copy, pricing page, local Pro preview, and upgrade-click analytics only. No Stripe, RevenueCat, or live checkout.",
};

export function getPaymentStackAudit(): PaymentStackAudit {
  return PAYMENT_STACK_AUDIT;
}

export function isLiveBillingAvailable(): boolean {
  return PAYMENT_STACK_AUDIT.checkoutImplemented;
}
