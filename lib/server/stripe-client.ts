import "server-only";

import Stripe from "stripe";

import { getStripeBillingConfig } from "@/lib/billing/stripe-config";

let client: Stripe | null = null;

export function getStripeClient(): Stripe | null {
  const config = getStripeBillingConfig();
  if (!config.enabled || !config.secretKey) return null;
  if (!client) {
    client = new Stripe(config.secretKey);
  }
  return client;
}

export function requireStripeClient(): Stripe {
  const stripe = getStripeClient();
  if (!stripe) {
    throw new Error("STRIPE_NOT_CONFIGURED");
  }
  return stripe;
}
