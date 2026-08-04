import "server-only";

import { PRO_PRICE_FALLBACK } from "@/lib/billing/billing-display-constants";
import {
  getStripeBillingConfig,
  isStripeConfigured,
} from "@/lib/billing/stripe-config";

export function formatStripeUnitAmount(
  unitAmount: number,
  currency: string,
  interval = "month",
): string {
  const major = unitAmount / 100;
  const amount = new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: currency.toUpperCase(),
  }).format(major);
  return `${amount}/${interval}`;
}

/** Resolve displayed Pro price from Stripe price id (server-only). */
export async function resolveProPriceLabel(): Promise<string> {
  if (!isStripeConfigured()) return PRO_PRICE_FALLBACK;

  const config = getStripeBillingConfig();
  if (!config.secretKey || !config.priceId) return PRO_PRICE_FALLBACK;

  try {
    const { default: Stripe } = await import("stripe");
    const client = new Stripe(config.secretKey);
    const price = await client.prices.retrieve(config.priceId);
    if (!price.active || price.unit_amount == null || !price.currency) {
      return PRO_PRICE_FALLBACK;
    }
    return formatStripeUnitAmount(
      price.unit_amount,
      price.currency,
      price.recurring?.interval ?? "month",
    );
  } catch {
    return PRO_PRICE_FALLBACK;
  }
}
