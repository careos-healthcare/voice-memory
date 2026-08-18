import "server-only";

import { isStripeConfigured } from "@/lib/billing/stripe-config";
import { resolveProPriceLabel } from "@/lib/billing/pro-price-label";

export interface BillingPublicConfig {
  billingLive: boolean;
  proPriceLabel: string;
  stripeCheckoutLine: string;
}

export async function getBillingPublicConfig(): Promise<BillingPublicConfig> {
  const billingLive = isStripeConfigured();
  const proPriceLabel = await resolveProPriceLabel();

  return {
    billingLive,
    proPriceLabel,
    stripeCheckoutLine: billingLive
      ? "Secure checkout via Stripe"
      : "Stripe not configured in this environment",
  };
}
