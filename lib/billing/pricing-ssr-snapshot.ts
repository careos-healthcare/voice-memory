import "server-only";

import { getBillingPublicConfig } from "@/lib/billing/billing-public-config";

export type PricingCheckoutQuery = "success" | "cancel" | null;

export interface PricingSsrSnapshot {
  billingLive: boolean;
  billingState: "configured" | "disabled";
  stripeCheckoutLine: string;
  proPriceLabel: string;
  checkoutQuery: PricingCheckoutQuery;
}

export async function getPricingSsrSnapshot(
  checkout?: string | string[] | null,
): Promise<PricingSsrSnapshot> {
  const publicConfig = await getBillingPublicConfig();
  const raw = Array.isArray(checkout) ? checkout[0] : checkout;
  const checkoutQuery: PricingCheckoutQuery =
    raw === "success" || raw === "cancel" ? raw : null;

  return {
    billingLive: publicConfig.billingLive,
    billingState: publicConfig.billingLive ? "configured" : "disabled",
    stripeCheckoutLine: publicConfig.stripeCheckoutLine,
    proPriceLabel: publicConfig.proPriceLabel,
    checkoutQuery,
  };
}
