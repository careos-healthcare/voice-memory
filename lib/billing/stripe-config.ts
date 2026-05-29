/**
 * Stripe configuration — fail closed when env is incomplete.
 */

export interface StripeBillingConfig {
  enabled: boolean;
  secretKey: string | null;
  webhookSecret: string | null;
  priceId: string | null;
  appUrl: string | null;
  missing: string[];
}

export function getStripeBillingConfig(): StripeBillingConfig {
  const secretKey = process.env.STRIPE_SECRET_KEY?.trim() || null;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET?.trim() || null;
  const priceId = process.env.STRIPE_PRO_PRICE_ID?.trim() || null;
  const appUrl =
    process.env.NEXT_PUBLIC_APP_URL?.trim() ||
    process.env.APP_URL?.trim() ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null);

  const missing: string[] = [];
  if (!secretKey) missing.push("STRIPE_SECRET_KEY");
  if (!webhookSecret) missing.push("STRIPE_WEBHOOK_SECRET");
  if (!priceId) missing.push("STRIPE_PRO_PRICE_ID");
  if (!appUrl) missing.push("NEXT_PUBLIC_APP_URL");

  const enabled = missing.length === 0;

  return {
    enabled,
    secretKey,
    webhookSecret,
    priceId,
    appUrl,
    missing,
  };
}

export function isStripeConfigured(): boolean {
  return getStripeBillingConfig().enabled;
}
