import "server-only";

import { PRO_PRICE_FALLBACK } from "@/lib/billing/billing-display-constants";
import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";

export function formatStripeUnitAmount(
  unitAmount: number,
  currency: string,
  interval = "month",
): string {
  const major = unitAmount / 100;
  const symbol = currency.toLowerCase() === "gbp" ? "£" : `${currency.toUpperCase()} `;
  return `${symbol}${major.toFixed(2)}/${interval}`;
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
    if (!price.active || price.unit_amount == null) return PRO_PRICE_FALLBACK;
    return formatStripeUnitAmount(
      price.unit_amount,
      price.currency ?? "gbp",
      price.recurring?.interval ?? "month",
    );
  } catch {
    return PRO_PRICE_FALLBACK;
  }
}
